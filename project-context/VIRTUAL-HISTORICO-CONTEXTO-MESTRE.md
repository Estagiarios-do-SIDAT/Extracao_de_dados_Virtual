# Virtual — Histórico e Contexto Mestre

Contexto de manutenção da apuração FAIA/FARC da Virtual: de onde vieram as
regras, o que foi validado, quais divergências das planilhas estão comprovadas e
o que ainda depende de decisão. A regra vigente está em
`docs/virtual-calculation.md`. Este arquivo registra **por que** ela é assim.

Novas intervenções entram como seção nova no fim (seção 12), com data.

---

## 1. Objetivo

Reproduzir, direto do SDM (`mdb`), as abas `Chamados_TCU` e `Chamados_24x7` das
planilhas mensais **Planilha_NMS_TCU** da Virtual, que hoje são montadas à mão.

São duas planilhas por mês:

| Planilha | Conteúdo | Valor mensal |
|---|---|---|
| DCIM | rotinas agendadas do serviço de DCIM | R$ 16.000,00 |
| Manutenção | demais chamados atendidos pela Virtual | R$ 22.000,00 |

## 2. Planilhas usadas como fonte de verdade

| Ciclo | Arquivos | Linhas | Salvo em |
|---|---|---|---|
| 25/09–24/10/2025 | `Planilha_NMS_TCU - DCIM/Manutenção - 25-09-2025 a 24-10-2025 - protegida.xlsx` | 15 + 12 | fev/2026 |
| 01–30/05/2026 | `Planilha_NMS_TCU - DCIM/Manutenção - 01-05-2026 a 30-05-2026.xlsx` | 6 + 5 | 22 e 25/06/2026 |
| 01–30/07/2026 | `Planilha_NMS_TCU - DCIM/Manutenção - 01-07-2026 a 30-07-2026.xlsx` | 15 + 7 | 10 e 11/08/2026 |

Ficam em `Documentos e Relatórios/Virtual` (maio) e na pasta compartilhada
*Estágio Sidat TCU*: julho/2026 em *Indicadores e Relatórios de Serviços* e o
ciclo de 2025 em *Checklist Relatório/Ciclo 25.09 A 24.10.2025*.

Todas partem do mesmo modelo (criado em 26/01/2026). Colunas A–H são coladas
(ID, descrição, tipo, prioridade, regime e três datas) e I–W são fórmulas.
O arquivo de 2025 não tem a coluna *Descrição do Chamado*.

O nome do arquivo não marca o fim real do período: a planilha
"01-07-2026 a 30-07-2026" traz chamados abertos em 31/07.

## 3. Decisões técnicas

| Tema | Decisão | Base |
|---|---|---|
| População | I/R aberto no período, com passagem pelo grupo `Fornecedores - Virtual` (TR para o grupo ou nascido nele), exceto Não resolvido/Cancelado/Cancelada | 60/60 linhas das planilhas; nenhuma linha aberta fora do próprio ciclo |
| Período | pela **abertura**; aberto no período e resolvido depois **entra** | seção 6 |
| DCIM | `log_agent` = automação (`Usuário de Serviço - ServiceDesk`) **e** IC `dcim` | 60/60; coincide com `%AFFECTED_RC=dcim` da mensagem de criação em toda a população de 2025–2026 (267 chamados) |
| Regime | Parâmetros por Tipo + Prioridade (P1/P2 = 24x7) | nenhum campo do SDM traz o regime |
| Abertura | `open_date` | exato nas linhas não digitadas à mão |
| Início | 1ª mudança de status (ST/RE), dentro de uma passagem pela Virtual, para status fora da fila (`OP`, `REOP`) | exato em todas as linhas não digitadas; 1647942 vai direto para *Agendado* |
| Resolução | `resolve_date`; se vazio, último RE, salvo chamado em atendimento aberto | 1651461 (`Em homologação pelo fiscal` limpa `resolve_date`) |
| Horário comercial | 08–20h, seg–sex, fora das datas com `Conta_SLA = 'N'`, calculado dia a dia | reproduz todas as células K/M com fórmula íntegra |
| 24x7 | comerciais = 0; excesso sobre tempo corrido | planilhas de 2026; FARC real em 1719182 (28,218) |
| Índice FAIA | horas × fator (com ×24) | 1ª linha de todas as abas, FARC inteiro, FAIA real de 1714513 (3,226) |
| Status de espera | não suspendem a contagem | as fórmulas só usam as três datas |
| Saída | uma consulta de referência com `@Planilha` e dois result sets; Power BI em dois arquivos, um por aba | motor único, bloco idêntico nos três arquivos |

## 4. Identidades no SDM

| Item | UUID |
|---|---|
| Grupo `Fornecedores - Virtual` | `0x21679DF702A0EC478B1468D89E769836` |
| Contato `Usuário de Serviço - ServiceDesk` (automação) | `0xC6BB355348EE414B9EAA9870ADA5C9E5` |
| IC `dcim` | `0xA39FE15C43351C41BA9478BA4000BAF5` |

Nos logs, o grupo sempre aparece como `Fornecedores - Virtual`. Entre 2025 e
2026 não houve outro nome nas transferências.

Há outros ICs parecidos (`dcim3`, `dcim4`, `dcim-3`) que **não** marcam
chamados DCIM.

## 5. Calendário e parâmetros

- O calendário (43 datas, 2025–2026) foi transcrito da tabela `tblCalendarioTCU`
  das planilhas de 2026, sem acréscimos, e não foi conferido com fonte oficial.
  O arquivo de 2025 tinha 26/11/2025 no lugar de 26/12/2025.
- `Conta_SLA = 'N'`: dia sem horário comercial. 05/03/2025 (`s`/`S`) conta como
  dia cheio. Não há contagem parcial de dia.
- **Atualização anual:** bloco `[2]` do motor (`#Virt_Calendario`) na referência,
  depois copiado para os dois arquivos do Power BI.
- A matriz de parâmetros (9 linhas) é a mesma nas seis planilhas.

## 6. Período: abertura e resolução tardia

Evidências:

- As 60 linhas das planilhas foram abertas dentro do próprio ciclo.
- Chamados abertos **antes** e resolvidos **dentro** do ciclo não aparecem:
  1687306 (maio), 1711203, 1711204 e 1651174 (julho).
- Abertos no ciclo e resolvidos **depois**:
  - 2025: os quatro que já estavam resolvidos quando a planilha foi fechada
    estão nela, com a resolução real e FARC (1650824, 1650826, 1651064,
    1652305; FARC 0; 39,98; 25,08; 84,59 na planilha).
  - maio/2026: 1701556 (resolvido em 23/06) ausente, mas a planilha de maio está
    incompleta de qualquer forma (seção 8).
  - julho/2026: 1718467 (31/08) e 1719167 (03/08) ausentes.

Decisão: o chamado pertence ao mês de **abertura** e **entra** mesmo se resolvido
depois, com a resolução real. Excluí-lo faria com que nunca fosse apurado,
porque o mês da resolução também não o contém. Os chamados longos são justamente
os que geram FARC: 1651174 chega a 410,48 e 1701556 a 52,34.

## 7. Caso 1644738 — resolvido depois de sair da Virtual

Solicitação P3 (Manutenção, TCU), ciclo de 2025:

```text
25/09 14:48:51  INIT  COI (Vinicius)                         abertura
25/09 14:50:51  ST    Aberto -> Em andamento                 (COI)
25/09 14:51:59  ST    Em andamento -> Aguarda atendimento    (COI)
25/09 14:52:00  TR    Grupo COI -> Fornecedores - Virtual    entrada
25/09 14:55:07  ST    Aguarda atendimento -> Em andamento    início (Rodrigo, Virtual)
26/09 17:42:42  ATTACHTDOC  "RAT Virtual TI 1644738.pdf"     Virtual conclui e anexa o RAT
29/09 10:22:28  TR    Grupo Fornecedores - Virtual -> COI    saída
29/09 13:13:13  SOLN  COI: "Conforme RAT Virtual TI ... em anexo"
29/09 13:15:04  resolve_date / close_date (sem evento RE)
```

Único chamado de 2025–2026 resolvido fora da Virtual. Não está na planilha do
ciclo de 2025. Pela consulta: horas comerciais de resolução 22,44 h contra meta
de 60 h, FARC 0. Parando na saída da Virtual seriam 19,56 h; parando no RAT,
14,90 h. Nenhuma alternativa muda o resultado.

Decisão: **mantido na apuração** (regra A), sem corte na saída. Um caso isolado
não sustenta nova regra. A ausência na planilha é compatível tanto com exclusão
deliberada quanto com omissão, que também ocorre em maio e julho. Pendência:
confirmar com a fiscalização se chamado devolvido ao COI antes da resolução
conta para a Virtual.

## 8. Validação

Consulta comparada célula a célula com as três rodadas de planilhas
(comparação em 01/10/2026):

| Ciclo | Planilha | SQL | Coincidentes | Só na SQL |
|---|---|---|---|---|
| 2025 | 27 | 30 | 27 | 1644738 (seção 7), 1650825 e 1651174 (sem resolução quando a planilha foi fechada) |
| maio/2026 | 11 | 23 | 11 | 9 DCIM abertos depois de 13/05, 1701344, 1701511, 1701556 |
| julho/2026 | 22 | 25 | 22 | 1712931 (omitido), 1718467 e 1719167 (resolvidos depois) |

Nos coincidentes, metas, excessos, fatores, índices, tipo e prioridade batem nos
três ciclos, salvo os pontos da seção 9. Nenhuma diferença foi atribuída a erro
da SQL.

**Maio incompleto.** A planilha DCIM de maio para em 13/05. Os 9 chamados DCIM
seguintes têm o mesmo registrador, IC, categoria e fluxo dos listados. Na
Manutenção faltam 1701344 e 1701511 (Incidentes P3 de Climatização, resolvidos
em 16/05); a planilha de julho lista incidente idêntico (1718320). Os 11 têm
FAIA e FARC zero. 1701556 tem FARC 52,34.

**Execução de um ano** (aberturas de set/2025 a ago/2026, 262 chamados): sem
duplicidade, nenhum sem início, nenhum sem regime, todos os ST/RE e TR
interpretados, 12 no 24x7, 25 com FARC > 0, 7 com FAIA > 0.

**Power BI x referência:** mesmas linhas e mesmos valores em maio/2026 (23
chamados) e na janela de 12 meses (01/10/2025–01/10/2026, 287 chamados). Tempo:
cerca de 30–40 s por arquivo.

## 9. Divergências comprovadas das planilhas

| Divergência | Ocorrências | Tratamento |
|---|---|---|
| `Horas Comerciais Resolução` da 1ª linha TCU da Manutenção é constante 0:16:00 | 1698592, 1713847 | regra |
| `Indice FAIA` sem ×24 em linhas copiadas | DCIM 2026; DCIM e Manutenção 2025 (sem efeito: excessos 0) | ×24 |
| `Horas Comerciais Resposta` do DCIM só trata o mesmo dia | DCIM (sem efeito nos casos vistos) | dia a dia |
| `Horas Comerciais Resposta` da Manutenção ignora `Conta_SLA` | só afetaria 05/03/2025 | `Conta_SLA` |
| Aproximação semanal da contagem de dias úteis | 1647942 (+12 h) | dia a dia |
| Regime digitado errado | 1703448 (`s`), 1719182 (`TCU` na aba 24x7) | Parâmetros |
| Fatores alterados por arrasto | 1718320 (1,2/1,4), 1720141 (2,2/2,4) | Parâmetros |
| Datas digitadas | 1704841 (sem segundos), 1716548 (resolução = início), 1717462 (texto, `#VALUE!`), 1698592 (início = abertura + 5 min), linhas de 2025 sem segundos | SDM |
| Descrição de outro chamado | 1704841 (texto de 1647146) | SDM |
| Vínculo externo `[1]Parâmetros` (arquivo de março/2026) | 24x7 de maio e julho, DCIM T2/V2 de maio | Parâmetros |
| Calendário de 2025 com 26/11 no lugar de 26/12 | 1650826, 1652305 (−12 h na planilha) | calendário atual |
| 24x7 de 2025 com contagem comercial | 1647146 | tempo corrido (2026) |

## 10. Arquivos

| Arquivo | Papel |
|---|---|
| `queries/consulta_virtual_faia_farc.sql` | referência: `@DataInicio`, `@DataFim`, `@Planilha`, dois result sets |
| `powerbi/consulta_virtual_chamados_tcu_power_bi.sql` | Power BI, aba TCU, janela de `@CoberturaMeses` (12) |
| `powerbi/consulta_virtual_chamados_24x7_power_bi.sql` | Power BI, aba 24x7 |
| `docs/virtual-calculation.md` | regra vigente |
| `docs/powerbi-query.md` | uso das consultas do Power BI |

Motor compartilhado: bloco entre `-- >>> MOTOR VIRTUAL` e `-- <<< MOTOR VIRTUAL`,
idêntico nos três arquivos. O SHA256 do bloco (fim de linha LF) vigente é o da
intervenção mais recente na seção 12.

## 11. Pendências

1. Chamado devolvido ao COI antes da resolução (seção 7): confirmar com a
   fiscalização.
2. Planilhas de maio/2026: confirmar com quem as monta que os 11 chamados ausentes
   foram omissão.
3. Calendário de 2027: incluir quando as datas forem publicadas.

## 12. Intervenções

### 2026-10-01 — criação da apuração

- Regras descobertas a partir das planilhas de 2025, maio e julho de 2026 e do
  `act_log` dos chamados (seções 3 a 9).
- Criadas a consulta de referência, as duas consultas do Power BI e a
  documentação funcional.
- Janela do Power BI definida em 12 meses fechados mais o mês corrente
  (`@CoberturaMeses = 12`). É o padrão do painel da Decision, permite comparar
  mês a mês e custa cerca de 30–40 s por consulta.
- README e este arquivo reescritos para a Virtual. O arquivo inicial era uma
  cópia do histórico do COI, sem conteúdo aplicável.
- SHA256 do motor (bloco com fim de linha LF):
  `8a6054a46d3059603bd538475893be49777fc44ae56a395be34993df8404dae9`.
