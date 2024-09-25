with itenscontratos as ( -- with 1 começa aqui --------------------------------------------------------------------------------------
SELECT 
	itc.Empresa_itens, itc.Contrato_itens, itc.Item_itens, 
	itc.Serv_itens as codigo_insumo_compra, 
	itc.Descr_itens as descricao_insumo_compra,
	itc.Cap_itens, itc.Categ_itens, 
	ig.Tipo_ins, itc.Qtde_itens, itc.Preco_itens, 
	CASE 
		when ad.total is null then (itc.Qtde_itens* itc.Preco_itens) 
		else ad.total
	end AS total
FROM UAU.dbo.ItensContrato itc
left join InsumosGeral ig 
on ig.Cod_ins = itc.Serv_itens 
LEFT join (
select *
from (
SELECT 
	Empresa_ItensAd, Contrato_ItensAd, NumAditivo_ItensAd, Serv_ItensAd, 
	Qtde_ItensAd, Preco_ItensAd, ValorContrato_ItensAd, ValorAditivo_ItensAd, 
	ItemCont_ItensAd, QtdeMedida_ItensAd, TotalMedido_ItensAd, (Qtde_ItensAd* Preco_ItensAd) as total,
	ROW_NUMBER() OVER (PARTITION BY Empresa_ItensAd, Contrato_ItensAd, Serv_ItensAd ORDER BY NumAditivo_ItensAd DESC) AS rn
FROM UAU.dbo.AditivoItensContrato ) as adv
where adv.rn = 1 ) ad 
on ad.Empresa_ItensAd = itc.Empresa_itens
and ad.Contrato_ItensAd = itc.Contrato_itens
and ad.Serv_ItensAd = itc.Serv_itens
and ad.ItemCont_ItensAd = itc.Item_itens
WHERE itc.Qtde_itens <> 0
and itc.Preco_itens <> 0
and itc.Empresa_itens in ('44')), -- with 1 termina aqui ----------------------------------------------------------------------------------------
mediaprecounit as ( -- with 2 começa aqui -------------------------------------------------------------------------------------------------------------
SELECT 
	im.Empresa_Item, im.Contrato_Item, m.Status_med, im.Ins_Item, im.ItensCont_Item,
	SUM( im.Qtde_Item * im.PrecoUnit_Item ) total_medido, 
	ROUND( (SUM( im.Qtde_Item * im.PrecoUnit_Item ) / 	SUM(im.Qtde_Item)), 8) as preco_medio -- erro de divisao por zero nao é aqui --- 
FROM UAU.dbo.ItensMedicao im
left join Medicoes m 
on m.Empresa_med = im.Empresa_Item
and m.Contrato_med = im.Contrato_Item 
and m.Cod_med = im.CodMed_Item 
--WHERE m.Status_med = 2
GROUP by im.Empresa_Item, im.Contrato_Item, m.Status_med, im.Ins_Item, im.ItensCont_Item), -- with 2 termina aqui ---------------------------------------
acompanhamento as ( -- with 3 começa aqui -------------------------------------------------------------------------------------------------------------
SELECT 
	Empresa_aec, Contrato_aec, Item_aec, Serv_aec, 
	SUM( Qtde_aec) qtde
FROM AcompExecContrato 
left join Medicoes m 
on m.Empresa_med = Empresa_aec 
and m.Contrato_med = Contrato_aec
and m.Cod_med = CodMed_aec
WHERE m.Status_med = 2
GROUP by Empresa_aec, Contrato_aec, Item_aec, Serv_aec
) -- with 3 termina aqui ---------------------------------------
SELECT 
	itc.Empresa_itens, ics.Obra_ItSi, itc.Contrato_itens, c.Objeto_cont, 
	itc.Item_itens, itc.codigo_insumo_compra, 
	itc.descricao_insumo_compra,  ics.Ins_ItSi as codigo_insumo_planejamento, ics.Ins_ItSi as descricao_insumo_planejamento,
	itc.Cap_itens,  ics.Produto_ItSi, ics.ContratoPl_ItSi, itc.Categ_itens, ics.ItemPl_ItSi, ics.Serv_ItSi,
	CASE itc.Tipo_ins
    	when 1 then '1 - MÃO-DE-OBRA'
		when 2 then '2 - EQUIPAMENTOS'
		when 3 then '3 - MATERIAIS'
		when 4 then '4 - SERVIÇOS'
		when 5 then '5 - TRANSPORTE'
		else '0'
    END as Tipo_insumo_compra,
	CASE -- inicio calculo preço medio usado
		-- caso o preço medio que vem dos itens de medição seja nulo vai usar o preço normal 
		when mp.preco_medio is null then itc.Preco_itens
		else mp.preco_medio
	END as preco_medio,
	ROUND( itc.total / itc.Preco_itens, 6) as qtde_reajustada,
	itc.total as total_reajustado, 
	1 AS porcentagens, -- porcentagem usada para calculo de medido e saldo --- no vinculo por fora a porcentagem sempre será 1---
	CASE -- inicio do calculo de quantidade medida --- 
		-- caso a quantidade medida + acompanhada for nula zero, se não é a qtde acompnhada+ medida multiplicada pela porcentagem 
		WHEN ac.qtde IS NULL THEN 0
		else (ac.qtde )		
	END as qtde_medido,
	ROUND( CASE -- inicio de calculo de total_medido_ins_compra -------------
		-- caso nao tenha quantidade medida e acompanhada zero, se não pega o preço medio e multiplica pela quadtidade acompnhada + medida e multiplica pela porcentagem
		when ac.qtde is null then 0
		ELSE ( (
				CASE 
					when mp.preco_medio is null then itc.Preco_itens
					else mp.preco_medio
				END)*(ac.qtde )
		) 
	END, 2 ) as total_medido_ins_compra,
	ROUND( itc.total / itc.Preco_itens, 6) - (CASE -- inicio do calculo de quantidade medida --- 
		-- caso a quantidade medida + acompanhada for nula zero, se não é a qtde acompnhada+ medida multiplicada pela porcentagem 
		WHEN ac.qtde IS NULL THEN 0
		else (ac.qtde )		
	END) AS saldo_qtde,
(ROUND( itc.total / itc.Preco_itens, 6) - (CASE -- inicio do calculo de quantidade medida --- 
		-- caso a quantidade medida + acompanhada for nula zero, se não é a qtde acompnhada+ medida multiplicada pela porcentagem 
		WHEN ac.qtde IS NULL THEN 0
		else (ac.qtde )		
	END)) *itc.Preco_itens AS Saldo_total,
	CASE c.Estagio_Cont
		WHEN 1 THEN '01 - Em Andamento'
		WHEN 2 THEN '02 - Concluído'
		WHEN 3 THEN '03 - Em Elaboração'
		WHEN 4 THEN '04 - Em Análise'
		else ''
	END as Estagio,
	CASE c.Status_cont
		WHEN 0 THEN '0 - Não Aprovado'
		WHEN 1 THEN '1 - Aprovado'
		WHEN 2 THEN '2 - Em Aditivo'
	END as Status,
	CASE c.Situacao_cont
		WHEN 0 THEN '0 - Andamento'
		WHEN 1 THEN '1 - Paralisado'
		WHEN 2 THEN '2 - Cancelado'
		WHEN 3 THEN '3 - Concluído'
		WHEN 4 THEN '4 - Em Encerramento'
		else ''
	END as Situacao, c.Obs_cont, 'Vinculado por Fora' as observacao_interna, c.Obra_cont 
from itenscontratos itc
left join mediaprecounit mp
on mp.Empresa_Item = itc.Empresa_itens 
and mp.Contrato_Item = itc.Contrato_itens
and mp.Ins_Item = itc.codigo_insumo_compra
and mp.ItensCont_Item = itc.Item_itens
left join acompanhamento ac
on ac.Empresa_aec = itc.Empresa_itens 
and ac.Contrato_aec = itc.Contrato_itens
and ac.Item_aec = itc.Item_itens
and ac.Serv_aec = itc.codigo_insumo_compra
left join contratos c
on c.Empresa_cont = itc.Empresa_itens
and c.Cod_cont = itc.Contrato_itens
left join ItensContSi ics
on ics.Empresa_ItSi = itc.Empresa_itens 
and ics.Contrato_ItSi = itc.Contrato_itens
and ics.Item_ItSi = itc.Item_itens
WHERE itc.Empresa_itens in ('44')
and ics.Obra_ItSi is Null
and c.Obra_cont in ('60100', 'O4120')