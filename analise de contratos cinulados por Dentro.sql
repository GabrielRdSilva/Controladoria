with itenscontratos as ( -- with 1 começa aqui --------------------------------------------------------------------------------------
SELECT 
	itc.Empresa_itens, itsi.Obra_ItSi, itc.Contrato_itens, itc.Item_itens,  ctg.contagem,
	itc.Serv_itens as codigo_insumo_compra, 
	itc.Descr_itens as descricao_insumo_compra, 
	itsi.Ins_ItSi as codigo_insumo_planejamento, 
	itsi.Descr_ins as descricao_insumo_planejamento,
	itc.Cap_itens,itsi.Produto_ItSi, itsi.ContratoPl_ItSi, itc.Categ_itens, itsi.ItemPl_ItSi, itsi.Serv_ItSi,
	ig.Tipo_ins, itc.Qtde_itens, itc.Preco_itens, itsi.total
FROM UAU.dbo.ItensContrato itc
left join (  -- subconsulta 1 começa aqui ------------------------------------------
SELECT 
	 Total_ItSi as total, Empresa_ItSi, Contrato_ItSi, Item_ItSi, Obra_ItSi, Ins_ItSi, ig.Descr_ins, Serv_ItSi, ItemPl_ItSi, Produto_ItSi, ContratoPl_ItSi 
FROM ItensContSi
left join InsumosGeral ig 
on ig.Cod_ins = Ins_ItSi
) as itsi -- sub consulta 1 termina aquiiiii -------------------------------------------------
on itsi.Empresa_ItSi = itc.Empresa_itens
and itsi.Contrato_ItSi = itc.Contrato_itens
and itsi.Item_ItSi = itc.Item_itens 
left join InsumosGeral ig 
on ig.Cod_ins = itc.Serv_itens 
left join (
SELECT 
	 Empresa_itens,Contrato_itens, Serv_itens, Obra_ItSi, itc.Item_itens, COUNT(DISTINCT itsi.Ins_ItSi) as contagem 
	--COUNT(itc.Item_itens) 
FROM UAU.dbo.ItensContrato itc
left join ItensContSi as itsi -- sub consulta 1 termina aquiiiii -------------------------------------------------
on itsi.Empresa_ItSi = itc.Empresa_itens
and itsi.Contrato_ItSi = itc.Contrato_itens
and itsi.Item_ItSi = itc.Item_itens 
WHERE itc.Qtde_itens <> 0
GROUP by itc.Empresa_itens, itsi.Obra_ItSi, itc.Contrato_itens, itc.Serv_itens, itc.Item_itens) ctg
on ctg.Empresa_itens = itc.Empresa_itens
and ctg.Contrato_itens = itc.Contrato_itens
and ctg.Serv_itens = itc.Serv_itens 
and ctg.Obra_ItSi = itsi.Obra_ItSi
and ctg.Item_itens = itc.Item_itens
WHERE itc.Qtde_itens <> 0
and itc.Preco_itens <> 0
and itsi.total <> 0
and itc.Empresa_itens in ('44')), -- with 1 termina aqui ----------------------------------------------------------------------------------------
mediaprecounit as ( -- with 2 começa aqui -------------------------------------------------------------------------------------------------------------
SELECT 
	im.Empresa_Item, im.Contrato_Item, m.Status_med, im.Ins_Item, im.ItensCont_Item,
	SUM( im.Qtde_Item * im.PrecoUnit_Item ) total_medido, 
	ROUND( (SUM( im.Qtde_Item * im.PrecoUnit_Item ) / 	SUM(im.Qtde_Item)), 8) as preco_medio  ---não tem erro 
FROM UAU.dbo.ItensMedicao im
left join Medicoes m 
on m.Empresa_med = im.Empresa_Item
and m.Contrato_med = im.Contrato_Item 
and m.Cod_med = im.CodMed_Item 
WHERE m.Status_med = 2
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
), -- with 3 termina aqui ---------------------------------------
aditivo as ( --- with 4 começa aqui -------------------------------------
SELECT 
	Empresa_ItensAd, Contrato_ItensAd, NumAditivo_ItensAd, Serv_ItensAd, 
	Qtde_ItensAd, Preco_ItensAd, ValorContrato_ItensAd, ValorAditivo_ItensAd, 
	ItemCont_ItensAd, QtdeMedida_ItensAd, TotalMedido_ItensAd, (ValorContrato_ItensAd + ValorAditivo_ItensAd) as total,
	ROW_NUMBER() OVER (PARTITION BY Empresa_ItensAd, Contrato_ItensAd, Serv_ItensAd ORDER BY NumAditivo_ItensAd DESC) AS rn
FROM UAU.dbo.AditivoItensContrato 
) -- with 4 termina aquii -----------------------
SELECT 
	itc.Empresa_itens, itc.Obra_ItSi, itc.Contrato_itens, c.Objeto_cont, 
	itc.Item_itens, itc.codigo_insumo_compra, 
	itc.descricao_insumo_compra, itc.codigo_insumo_planejamento, itc.descricao_insumo_planejamento, 
	itc.Cap_itens, itc.Produto_ItSi, itc.ContratoPl_ItSi,  itc.Categ_itens, itc.ItemPl_ItSi, itc.Serv_ItSi, 
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
	END as preco_medio, --não tem erro or zero 
	CASE -- inicio quantidade reajustada ---------
		-- caso o preço medio que vem de medição for não nulo pega o total e divide por ele, caso seja pega o total e divide pelo valor normal do contrato 
		when  mp.preco_medio is not null then ROUND( itc.total / mp.preco_medio, 6)
		else ROUND( case
		when c.Status_cont = 2 and ad.total is not null then ad.total
		else itc.total 
	end  / itc.Preco_itens, 6)
	END as qtde_reajustada, -- termino de quantidade reajustada --- 
	case
		when c.Status_cont = 2 and ad.total is not null then ad.total
		else itc.total 
	end as total_reajustado, 
	ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6) AS porcentagens, -- porcentagem usada para cálculo de medido e saldo
CASE -- início do cálculo de quantidade medida
    WHEN ac.qtde IS NULL THEN 0
    ELSE (ac.qtde * ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6))		
END as qtde_medido,
ROUND( CASE -- início do cálculo de total_medido_ins_compra
    WHEN ac.qtde IS NULL THEN 0
    ELSE ((CASE 
            WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
            ELSE mp.preco_medio
          END) * (ac.qtde * ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6))) 
END, 2) as total_medido_ins_compra, 
CASE -- início verificação se deve ser zerada a qtde de saldo
    WHEN (
        CASE -- início de cálculo de saldo_qtde
            WHEN ac.qtde IS NULL THEN
                CASE
                    WHEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6) IS NOT NULL 
                    THEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6)
                    ELSE ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / itc.Preco_itens, 6)
                END
            ELSE
                (CASE
                    WHEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6) IS NOT NULL 
                    THEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6)
                    ELSE ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / itc.Preco_itens, 6)
                END) - (ac.qtde * ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6))
        END / (CASE -- início quantidade reajustada
                WHEN mp.preco_medio IS NOT NULL THEN ROUND((case 
                                                          when c.Status_cont = 2 and ad.total is not null then ad.total 
                                                          ELSE itc.total 
                                                        END) / mp.preco_medio, 6)
                ELSE ROUND((case 
                            when c.Status_cont = 2 and ad.total is not null then ad.total 
                            ELSE itc.total 
                           END) / itc.Preco_itens, 6)
            END)
    ) < 0.0001 THEN 0
    ELSE (
        CASE -- início de cálculo de saldo_qtde
            WHEN ac.qtde IS NULL THEN
                CASE
                    WHEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6) IS NOT NULL 
                    THEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6)
                    ELSE ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / itc.Preco_itens, 6)
                END
            ELSE
                (CASE
                    WHEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6) IS NOT NULL 
                    THEN ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / mp.preco_medio, 6)
                    ELSE ROUND((case 
                                when c.Status_cont = 2 and ad.total is not null then ad.total 
                                ELSE itc.total 
                              END) / itc.Preco_itens, 6)
                END) - (ac.qtde * ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6))
        END
    )
END AS saldo_qtde,
CASE -- início verificação se o saldo total deve ser zerado
    WHEN (ROUND (CASE -- início de cálculo do saldo total
            WHEN ac.qtde IS NULL THEN (case 
                                        when c.Status_cont = 2 and ad.total is not null then ad.total 
                                        ELSE itc.total 
                                       END)
            ELSE ((case 
                    when c.Status_cont = 2 and ad.total is not null then ad.total 
                    ELSE itc.total 
                   END) - ( ac.qtde * ( ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6)) * (CASE 
                                        WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                                        ELSE mp.preco_medio
                                    END)))
        END, 2) / (case 
                    when c.Status_cont = 2 and ad.total is not null then ad.total 
                    ELSE itc.total 
                  END)) < 0.00001 THEN 0
    ELSE (ROUND (CASE -- início de cálculo do saldo total
            WHEN ac.qtde IS NULL THEN (case 
                                        when c.Status_cont = 2 and ad.total is not null then ad.total 
                                        ELSE itc.total 
                                       END)
            ELSE ((case 
                    when c.Status_cont = 2 and ad.total is not null then ad.total 
                    ELSE itc.total 
                   END) - ( ac.qtde * ( ROUND(case 
		when itc.contagem = 1 then 1
		else ((case 
                when c.Status_cont = 2 and ad.total is not null then ad.total 
                ELSE itc.total 
              END) / 
              (CASE 
                  WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                  ELSE mp.preco_medio
               END) / itc.Qtde_itens)
	end, 6)) * (CASE 
                                        WHEN mp.preco_medio IS NULL THEN itc.Preco_itens
                                        ELSE mp.preco_medio
                                    END)))
        END, 2))
END as Saldo_total, 
	CASE c.Estagio_Cont
		WHEN 1 THEN '01 - Em Andamento'
		WHEN 2 THEN '02 - Concluído'
		WHEN 3 THEN '03 - Em Elaboração'
		WHEN 4 THEN '04 - Em Análise'
		else ''
	END as Estagio,
	case c.Status_cont
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
	END as Situacao, c.Obs_cont, 'Vinculado por Dentro' as observacao_interna
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
and c.Obra_cont = itc.Obra_ItSi
left join (
select *
from aditivo
WHERE rn = 1) ad
on ad.Empresa_ItensAd = itc.Empresa_itens
and ad.Contrato_ItensAd = itc.Contrato_itens
and ad.Serv_ItensAd = itc.codigo_insumo_compra
and ad.ItemCont_ItensAd = itc.Item_itens
WHERE itc.Empresa_itens in ('44')
AND itc.descricao_insumo_planejamento IS NOT NULL
AND itc.Obra_ItSi in ('60100', 'O4120')