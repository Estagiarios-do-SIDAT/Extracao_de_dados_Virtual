# Virtual — Histórico e Contexto Mestre

Contexto de manutenção da apuração FAIA/FARC da Virtual: de onde vieram as
regras, o que foi validado, quais divergências das planilhas estão comprovadas e
o que ainda depende de decisão. A regra vigente está em
`docs/virtual-calculation.md`. Este arquivo registra **por que** ela é assim.

Novas intervenções entram como seção nova no fim (seção 12), com data.

---

## 1. Objetivo

Apurar, direto do SDM (`mdb`), FAIA e FARC da Virtual em duas grades por
regime (`Chamados_TCU` e `Chamados_24x7`).

**Estado vigente:** o motor depende só de dados do SDM e do arquivo de
feriados. O contrato (Edital PE 90028/2025, Anexo VII) define metas, fatores,
cobertura (Contagem), prioridades e nomenclatura; a mecânica dos tempos
(posse, primeiro atendimento e Tempo de Atendimento) é a lógica operacional da
Decision adaptada à posse da Virtual. Primeiro atendimento congelado.
Parâmetros ficam no próprio SQL (seção 12, intervenções de 2026-10-07). Não existe separação DCIM x Manutenção nem parâmetro
`@Planilha` (seção 12, intervenção de 2026-10-02 "remoção da dependência de
planilha").

As planilhas manuais **Planilha_NMS_TCU** foram a base da engenharia reversa.
Delas vieram os parâmetros, o calendário e o regime. Eram duas por mês:

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
| Escopo | I/R em status terminal (lista da Decision) e **grupo no fechamento = `Fornecedores - Virtual`** pelo histórico (última transferência de grupo até o fechamento foi entrada na Virtual, ou nasceu nela sem transferência); o grupo atual não decide | regra do escopo FAIA da Decision ([3.2] de `consulta_faia_farc.sql`); decisão de 2026-10-02 |
| Período | data escolhida em `@DataReferencia`, semiaberto, sem substituição entre as datas. `FECHAMENTO` (padrão): `close_date`, status terminal, grupo atual e encerramento na Virtual. `RESOLUCAO`: `resolve_date` dentro de uma janela de posse da Virtual, `close_date` opcional | fechamento: regra da Decision ([1] de `consulta_faia_farc.sql`), decisão de 2026-10-02; chave de troca: 2026-10-05 |
| DCIM (removida da arquitetura em 2026-10-02) | `log_agent` = automação (`Usuário de Serviço - ServiceDesk`) **e** IC `dcim` | 60/60; coincide com `%AFFECTED_RC=dcim` da mensagem de criação em toda a população de 2025–2026 (267 chamados) |
| Regime | Parâmetros por Tipo + Prioridade (P1/P2 = 24x7) | nenhum campo do SDM traz o regime |
| Abertura | `open_date` | exato nas linhas não digitadas à mão |
| Início | 1º `Em andamento` (ST/RE para `FIP`) dentro de uma passagem pela Virtual: a captura da Decision; sem ele, 1ª atividade do `act_log` (exceto `TR`) na posse; sem atividade, a entrada | decisão de 2026-10-05 (fallback: Decision [4]/[7.1]); até então, 1ª mudança para fora da fila (`OP`, `REOP`), que em 1647942 pegava o *Agendado* |
| Resolução | `resolve_date`; se vazio, último RE, salvo chamado em atendimento aberto | 1651461 (`Em homologação pelo fiscal` limpa `resolve_date`) |
| Horário comercial | 08–20h, seg–sex, fora das datas com `Conta_SLA = 'N'`, calculado dia a dia | reproduz todas as células K/M com fórmula íntegra |
| 24x7 | comerciais = 0; excesso sobre tempo corrido | planilhas de 2026; FARC real em 1719182 (28,218) |
| Índice FAIA | horas × fator (com ×24) | 1ª linha de todas as abas, FARC inteiro, FAIA real de 1714513 (3,226) |
| Status de espera | pausam o Tsol: contam `Em andamento`, `Aberto, aguarda atendimento` e `Reaberto`; o resto da posse até a Resolução vai para `Tempo suspenso`. Linha de status: toda transição textual do `act_log` (ST, RE, RO, CL) e o `SOLN` como pausa | orientação do gerente de 2026-10-06 (Reaberto conta), que prevalece sobre a decisão de 2026-10-05 de manter só os ativos do Tempo de Atendimento da Decision |
| Posse | relógio começa na 1ª entrada na Virtual (abertura, se nasceu nela); saídas pausam, reentradas reativam, janelas somadas | janelas de posse da Decision ([8.1]); decisão de 2026-10-02 |
| Fechamento | `Data/Hora Fechamento` = `close_date` (= evento CL, ±1 s) | 265 chamados do escopo com CL: 258 no mesmo segundo, 7 com 1 s de diferença de gravação |
| Formato | 10 durações em texto `[h]:mm:ss`; cálculo em segundos; fatores e índices numéricos | igual às planilhas |
| Saída | uma consulta de referência com dois result sets de 40 colunas (blocos A, B, C, `Grupo`, `Indicador de Agendamento` e `Data de Encerramento Virtual`), um por regime; Power BI em dois arquivos, um por regime, com as mesmas 40 colunas | motor único, bloco idêntico nos três arquivos |

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

Decisão de 2026-10-01: mantido na apuração, sem corte na saída.

**Decisão vigente (2026-10-02):** o chamado continua na apuração, mas o relógio
da Virtual **para na saída** (regra geral da janela de responsabilidade,
seção 3). Janela atribuída: 25/09 14:48:51 → 29/09 10:22:28. Resultado:
Tsol 91:33:37, horas comerciais de resolução 19:33:37, FARC 0 (antes: 94:26:13,
22:26:13, FARC 0).

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

**Janela de responsabilidade (2026-10-02).** Na execução de um ano, 250 dos 262
chamados ficaram idênticos (tempos ao segundo e índices). Mudaram só os 12
chamados com saída da Virtual: 1644738 (resolvido fora) e 11 com mais de uma
passagem (1644896, 1645103, 1651174, 1675872, 1693493, 1698592, 1701511,
1702424, 1709362, 1712105, 1719182). Os valores novos foram conferidos com um
cálculo independente em Python (12/12). Índices alterados: FARC de 1644896
(3,485 → 3,483), 1645103 (2,088 → 2,085), 1651174 (410,483 → 410,469), 1709362
(12,106 → 0) e 1719182 (28,218 → 28,127). Power BI x referência continuou
idêntico (maio: 23; 12 meses: 290).

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
| Tempo fora da Virtual contado | 1698592, 1719182, 1644896, 1645103 | janela de responsabilidade |

## 10. Arquivos

| Arquivo | Papel |
|---|---|
| `queries/consulta_virtual_faia_farc.sql` | referência: `@DataInicio`, `@DataFim`, `@DataReferencia`, dois result sets |
| `powerbi/consulta_virtual_chamados_tcu_power_bi.sql` | Power BI, regime TCU, janela de `@CoberturaMeses` (12) |
| `powerbi/consulta_virtual_chamados_24x7_power_bi.sql` | Power BI, regime 24x7 |
| `docs/virtual-calculation.md` | regra vigente |
| `docs/powerbi-query.md` | uso das consultas do Power BI |
| `analysis/virtual-query-report-analysis.xlsx` | conferência Consulta x Relatório (apoio de validação; não é lida pelo motor) |

Motor compartilhado: bloco entre `-- >>> MOTOR VIRTUAL` e `-- <<< MOTOR VIRTUAL`,
idêntico nos três arquivos. O SHA256 do bloco (fim de linha LF) vigente é o da
intervenção mais recente na seção 12.

## 11. Pendências

1. Planilhas de maio/2026: confirmar com quem as monta que os 11 chamados
   ausentes foram omissão. Os 11 foram resolvidos dentro da Virtual. Não afeta
   a consulta, que não usa a planilha como critério de escopo.
2. Calendário de 2027: incluir quando as datas forem publicadas.

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

### 2026-10-02 — janela de responsabilidade e formato [h]:mm:ss

- Os 11 chamados de maio ausentes da planilha foram todos resolvidos dentro da
  Virtual (último grupo antes da resolução = `Fornecedores - Virtual`).
- Referência metodológica: A2B e Decision contam só o tempo de posse do grupo,
  com o relógio a partir da entrada e soma de todas as janelas (reposse). Para a
  Virtual, por decisão do usuário, o relógio continua partindo da **abertura**,
  como nas planilhas; o que se adota da A2B/Decision é o desconto do tempo fora
  do grupo depois da primeira entrada e a soma das passagens. A alternativa
  (relógio a partir da entrada) mudaria Tini/Tsol das 60 linhas validadas e
  zeraria o FAIA de 1714513 (3,226), cobrado na planilha de julho.
- Motor: novos blocos `#Virt_LinhaGrupo`, `#Virt_Janela`, `#Virt_Trecho` e
  `#Virt_Calculo`; tempos somados por trecho. Início, Resolução, população,
  DCIM/Manutenção e regime não mudaram.
- As 10 durações saem como `[h]:mm:ss`; o índice é calculado dos segundos, com o
  excesso arredondado em 6 casas, como antes.
- SHA256 do motor (bloco com fim de linha LF):
  `bbd85c126761c2426dcf640a8ba9aff5f200f3f58881e94ccc3554585b55bfb0`.

### 2026-10-02 — arquitetura de posse da Decision, período por fechamento e schema ampliado

Decisão do usuário: a planilha deixa de ser o árbitro da lógica temporal. A
Virtual passa a seguir o modelo de posse da Decision, com os parâmetros, o
calendário e o horário comercial próprios.

Modelo lido no SQL vigente da Decision (`queries/consulta_faia_farc.sql`):

| Tema | Decision | Virtual |
|---|---|---|
| Período | `close_date` no período ([1]) | `close_date` em `[@DataInicio, @DataFim)` |
| Escopo | grupo atual = Decision, tipo I/R/P, status terminal ([3]) | igual, com tipo I/R (sem parâmetros de P na Virtual) |
| Encerramento no fornecedor | nasceu e ficou no grupo, ou a última transferência de grupo foi entrada na Decision ([3.2]) | igual, com a Virtual |
| Início | primeira entrada no grupo; se nasceu nele, `open_date` ([4], [3.3.1]) | igual |
| Posse | linha do tempo de grupo, janelas em posse, soma de todas ([8.1]) | igual, em ordem de `system_time` e `act_log.id` |
| Primeiro atendimento | primeiro `Em andamento` depois da entrada ([4]) | primeira mudança de status para fora da fila, dentro da posse (regra da Virtual) |
| Suspensão | status suspensos e SOLN→SRVY_SENT descontados | não há; a Virtual não suspende |

Efeito (fechamentos de 01/01/2025 a 02/10/2026):

- saíram 21 chamados: 1644738 e 1651174 (encerraram no COI) e 19 sem
  `close_date` (ainda em homologação, em andamento ou em
  `Em homologação pelo fiscal`, como 1651461 e 1693493);
- dos 273 que ficaram, 269 mudaram de tempo: deixa de contar o intervalo entre a
  abertura e a primeira entrada (mediana de 7 min; máximo de 11,6 dias, em
  1691112). Os 4 que não mudaram nasceram na Virtual;
- índices alterados em 21 chamados. FAIA zerado em 6 (1655273, 1682297,
  1685073, 1691112, 1691157, 1714513); FARC alterado em 16, zerado em 1691112.
  O FAIA de 1714513 (3,226, cobrado na planilha de julho) cai a 0, porque
  quase todo o tempo de resposta era do COI;
- os valores novos foram conferidos com cálculo independente em Python (273/273).

Schema: 36 colunas. Bloco A (identificação e datas, com `Data/Hora Fechamento`
depois de `Data/Hora Resolução`), bloco B (as 15 colunas de apuração, na mesma
ordem) e bloco C (colunas de contexto da Decision: `Status`, `Categoria`,
`Responsável Abertura`, `Responsável Atendimento`, `Item de Configuração`,
`Data Entrada Grupo Virtual`, `Meta Primeiro Atendimento`, `Indicador
Reabertura`, `Acordo Prazo`, `Acordo Qualidade`, `Justificativa`,
`Meta Atendimento`). Colunas da Decision com o mesmo conceito de uma coluna da
Virtual não foram repetidas; `Tempo suspenso` não tem equivalente.

As seções 6 e 7 descrevem a regra de período e o caso 1644738 de antes desta
intervenção. Na regra vigente o período é o do fechamento e o 1644738 fica fora
do escopo, por ter encerrado no COI.

SHA256 do motor (bloco com fim de linha LF):
`111ce0ac9c3a85fbb5077393885f7824cf4ba95f6417fd4083d87bd762b4fecd`.

### 2026-10-02 — coluna `Tempo suspenso`

- Mantido o mapeamento `Tempo Total Decision` → `Tsol (h)`, sem coluna
  `Tempo Total Virtual`.
- Incluída `Tempo suspenso` no bloco C, na posição 31 (depois de
  `Data Entrada Grupo Virtual`, como na ordem relativa da Decision). Vale sempre
  `0:00:00`, porque a regra da Virtual não suspende a contagem; não é descontada
  de nenhum tempo, excesso ou índice.
- Schema: 37 colunas na referência e 38 no Power BI (com `Planilha`).
- Validação: mesmos 273 chamados (fechamentos de 01/01/2025 a 02/10/2026),
  0 diferenças nas 36 colunas anteriores; Power BI x referência na janela de 12
  meses: 273 = 273, 0 diferenças.
- SHA256 do motor (bloco com fim de linha LF):
  `18f5b90b90ea55b372dbc3fce6027468d4241ebfc37eab78a20dc0fd47d767c3`.

### 2026-10-02 — remoção da dependência de planilha

Decisão do usuário: o motor deve depender só do SDM. A separação DCIM x
Manutenção e o parâmetro `@Planilha` serviram para reproduzir os dois arquivos
Excel durante a engenharia reversa e saíram da arquitetura funcional.

Motivação: com `@Planilha = N'DCIM'` como padrão, os chamados de Manutenção
(1698592, 1701895, 1701911, 1703448, todos P3/TCU encerrados na Virtual em maio)
passavam por todo o motor, mas eram cortados no SELECT final por
`WHERE Planilha = @Planilha`.

Mapeamento antes da remoção: a classificação só aparecia em `#Virt_Chamado`
(CASE com `@AgenteAutomacao` e `@IC_DCIM`), em `#Virt_Marco` (cópia), em
`#Virt_Saida` (coluna `Planilha`) e nos SELECTs finais (filtro na referência,
coluna e ordenação no Power BI). Nenhum cálculo dependia dela: metas, fatores,
regime, posse, FAIA e FARC usam Tipo + Prioridade e o histórico de grupo.

Removidos: `@Planilha` e sua validação, `@AgenteAutomacao`, `@IC_DCIM`, a coluna
derivada `planilha`, a coluna de saída `Planilha` e o filtro
`WHERE Planilha = @Planilha`. Comentários que citavam abas das planilhas foram
reescritos. O `Item de Configuração` continua na saída como dado do chamado.

Validação:

- maio/2026 (fechamento): Resultado 1 com 19 chamados (os 13 do antigo DCIM +
  os 6 da antiga Manutenção, incluindo os quatro acima) e Resultado 2 com 0, em
  uma execução;
- fechamentos de 01/01/2025 a 02/10/2026: mesmos 273 SDMs do `eb6b490`,
  0 diferenças nas 37 colunas mantidas;
- Power BI 12 meses: mesmos 273 SDMs (261 TCU, 12 24x7), 37 colunas,
  0 diferenças contra a versão publicada e contra a referência.

SHA256 do motor (bloco com fim de linha LF):
`37eb665ccc4ffcd0a7cefdf48427bb42830ab42c7d9848fa3093361449e36c73`.

### 2026-10-05 — chave `@DataReferencia` (resolução ou fechamento)

- Criada `@DataReferencia` no topo dos três arquivos, no mesmo espírito da troca
  `@COI_Antigo` / `@COI_Novo` do COI. `N'FECHAMENTO'` (padrão) filtra o período
  por `close_date`; `N'RESOLUCAO'`, por `resolve_date`. Outro valor (ou NULL)
  interrompe a consulta com
  `Valor inválido para @DataReferencia. Use RESOLUCAO ou FECHAMENTO.`
- A chave atua só em `#Virt_Periodo` (bloco [3]), por um `CASE` sobre a data
  escolhida, sem substituição entre as datas. O escopo passou a exigir
  `close_date` preenchido de forma explícita nos dois modos; todo chamado em
  status terminal do grupo já tinha `close_date`.
- Chamados resolvidos e ainda em `Em homologação` (17 em 05/10/2026, todos
  resolvidos entre 30/09 e 05/10/2026) não entram em nenhum modo até o
  fechamento.
- Validação, maio/2026:
  - `FECHAMENTO`: 19 TCU, 0 24x7 (idêntico ao `e82dd55`);
  - `RESOLUCAO`: 22 TCU, 1 24x7;
  - só em `RESOLUCAO`: 1687306, 1704301, 1704841 (24x7), 1704995, 1705168
    (resolvidos em maio, fechados em junho);
  - só em `FECHAMENTO`: 1696948 (resolvido em 29/04, fechado em 05/05);
  - 18 nos dois modos, com 0 diferenças nas 37 colunas.
- Power BI (12 meses até 05/10/2026): 275 chamados nos dois modos, iguais à
  referência; `FECHAMENTO` idêntico ao `e82dd55`.
- SHA256 do motor (bloco com fim de linha LF):
  `2861ee231b7448dbbb67f77d8c5b841ad4d90d0b403d33ff6f578ade9fe72405`.

### 2026-10-05 — semântica do modo `RESOLUCAO`

- O modo `RESOLUCAO` deixou de exigir `close_date`, status terminal, grupo atual
  e encerramento na Virtual. Passou a exigir `resolve_date` no período e a
  resolução dentro de uma janela de posse da Virtual (limites inclusivos;
  janela aberta vale para instantes posteriores). `FECHAMENTO` ficou como estava.
- Técnica: `#Virt_Periodo` tem um ramo por modo (`OPTION (RECOMPILE)`); no
  `RESOLUCAO`, os candidatos são chamados I/R resolvidos no período com grupo
  atual Virtual ou alguma transferência de grupo para ela. As janelas de posse
  passaram a ser montadas sobre os candidatos (`#Virt_Candidato`, bloco [6.1])
  antes da escolha final (`#Virt_Chamado`, bloco [6.2]). O `act_log` é lido até
  o fechamento ou, sem fechamento, até o último evento registrado; os tempos
  continuam terminando nos marcos.
- Os 17 chamados resolvidos e ainda em `Em homologação` (resolução de 30/09 a
  05/10/2026) foram todos resolvidos dentro de uma janela de posse da Virtual e
  entram com `RESOLUCAO`; com `FECHAMENTO` continuam fora. 1651174 (resolvido na
  Virtual em 20/07/2026, fechado no COI) entra só com `RESOLUCAO`; 1644738
  (resolvido pelo COI depois da saída) não entra em nenhum modo.
- Validação: `FECHAMENTO` idêntico ao estado anterior em maio, em 30/09–06/10 e
  em 12 meses; `RESOLUCAO` de maio igual ao anterior (23 chamados); em 12 meses,
  `RESOLUCAO` passou de 275 para 293 chamados (os 17 e 1651174), sem diferença
  de valor nos chamados que já existiam.
- SHA256 do motor (bloco com fim de linha LF):
  `3486b3440d54f753d48a5311729aba5ad1b2b02ece97a7a691ed5b1b80caaab9`.

### 2026-10-05 — coluna `Grupo`

- Incluída a coluna final `Grupo` (posição 38): `call_req.group_id` resolvido
  pelo nome em `ca_contact.last_name` (chave primária `contact_uuid`, a mesma
  junção já usada para o grupo inicial). Sem grupo, sai vazia. Desde 2025,
  todo `group_id` preenchido tem nome no cadastro e é um grupo
  (`contact_type` 2308).
- É informativa: mostra o grupo atual/final do chamado no SDM e não muda
  escopo, período, posse nem cálculo. 1651174 (resolvido na Virtual, fechado no
  COI) aparece em `RESOLUCAO` com `Grupo = COI`.
- Validação contra `af5a27a`: mesmos SDMs em maio, 30/09–06/10 e 12 meses, nos
  dois modos; 0 diferenças nas 37 colunas anteriores; nenhuma linha duplicada;
  Power BI x referência sem diferença nas 38 colunas.
- SHA256 do motor (bloco com fim de linha LF):
  `4b51f86c3d6c9f95be1f131c27fbaa5b767404d6e18b10a8cdc411a6cc4e5dda`.

### 2026-10-05 — pasta `analysis/`

- Incorporada a planilha de conferência `analysis/virtual-query-report-analysis.xlsx`
  (nome original: `Análise de chamados - Virtual TI.xlsx`, conteúdo preservado
  byte a byte). Uma aba por período (`01-05-2026 a 31-05-2026`,
  `01-07-2026 a 30-07-2026`), com a comparação bidirecional
  `Relatório | Retorna na consulta? | x | Consulta | Tem no relatório?`, feita
  por fórmulas `COUNTIF`.
- É evidência e apoio de validação humana. Não é dependência do motor SQL e não
  altera a fonte de verdade (SDM/MDB); `queries/` e `powerbi/` não leem nada de
  `analysis/`.

### 2026-10-05 — Tini/Tsol no modelo temporal da Decision

Objetivo: usar a Decision como referência funcional dos tempos, com
`Tini (h)` = Tempo Primeiro Atendimento, `Tsol (h)` = Tempo de Atendimento,
`Excesso Resposta (h)` = Primeiro Atendimento Excedido e
`Excesso Resolução (h)` = Tempo Atendimento Excedido. Regime, calendário,
horário 08–20, metas e fatores continuam os da Virtual.

Regra lida no SQL da Decision (`queries/consulta_faia_farc.sql`, sem alteração):

| Tema | Decision | Virtual antes | Virtual agora |
|---|---|---|---|
| Captura | 1º ST para `Em andamento` depois da entrada ([4]) | 1ª mudança para fora da fila, na posse | 1º `Em andamento` dentro da posse |
| Tempo Primeiro Atendimento | intervalo contínuo da entrada à captura, sem recorte de posse ([8.10]) | posse até o Início | posse até o Início |
| Tempo de Atendimento | da **última** entrada ao terminal (SOLN, senão resolução), só status ativos ([5], [7], [9.2]) | posse até a Resolução, todos os status | posse até a Resolução, só status ativos, todas as janelas |
| Status ativos | `Em andamento`, `Aberto, aguarda atendimento` ([9.2]) | — | iguais |
| Tempo suspenso | tempo fora dos ativos + SOLN→pesquisa ([9.2.1]) | `0:00:00` | posse até a Resolução − Tsol |

Decisões do usuário nesta rodada: pausar os status não ativos e mostrar o tempo
em `Tempo suspenso`; somar todas as janelas de posse (não só a última entrada);
Início = 1º `Em andamento` dentro da posse, com Tini só em tempo de posse.
Tini no modo literal da Decision mudaria 8 chamados, contando tempo com o COI
(ex.: 1731379, de 3:48:10 para 97:09:43); com a regra escolhida muda só 1647942.
Last entry (Decision) x todas as janelas: 17 chamados com Tsol diferente.
SOLN aparece em só 9 dos 293 chamados de 12 meses; o terminal continua sendo a
Resolução (`resolve_date`).

Particularidade da Decision, não reproduzida: o primeiro trecho da linha de
status é tratado como inativo só se a origem do primeiro evento for `Agendado`,
`Aguarda atendimento`, `Em homologação` ou `Em teste na TI`; uma origem
`Aguarda fornecedor` conta como ativa. A Virtual usa a regra coerente (na
abertura vale a origem do primeiro evento; depois, o destino de cada evento).
Com a heurística da Decision, 3 chamados teriam outro Tsol (1695931, 1731379,
1732031).

Efeito em 12 meses (293 chamados, `RESOLUCAO` ∪ `FECHAMENTO`, contra `52b9b93`):

- população idêntica em maio, 30/09–06/10 e 12 meses, nos dois modos;
- Tsol mudou em 293 e `Tempo suspenso` em 293; Horas Comerciais Resolução em
  246 e Não Comerciais em 74; Excesso Resolução e Indice FARC em 24;
  `Meta Atendimento` passou de `Não Atende` para `Atende` em 6 (1650826,
  1651064, 1651174, 1681392, 1683696, 1683711);
- Início, Tini, horas de resposta, Excesso Resposta e Indice FAIA mudaram só em
  1647942: Início de 07/10/2025 14:03:35 (*Agendado*) para 12/10/2025 08:24:55
  (`Em andamento`), Tini de 0:57:32 para 115:18:52 (42:53:57 comerciais),
  FAIA de 0 para 15,559667; Tsol de 121:16:31 para 5:57:39;
- maiores quedas de FARC: 1651174 (396,050167 → 0; 6331 h em `Agendado` dentro
  da posse), 1650826 (42,310278 → 0), 1667813 (43,333278 → 24,579889),
  1645571 (32,583389 → 24,062722), 1651064 (25,068833 → 0);
- totais em 12 meses: FAIA 0 → 15,559667; FARC TCU 848,385834 → 733,386167
  (`FECHAMENTO`) e 1297,433834 → 785,208056 (`RESOLUCAO`); FARC 24x7
  572,674000 → 571,918334. Maio/2026 sem mudança de índice.

Validação: Tini, Início e Tsol conferidos com cálculo independente em Python
(293/293); invariantes Tini = comerciais + não comerciais, Tsol = comerciais +
não comerciais, Tsol + Tempo suspenso = posse até a Resolução e excessos ≥ 0 em
293/293; os dois modos dão os mesmos valores para o mesmo chamado; Power BI x
referência sem diferença nas 38 colunas.

SHA256 do motor (bloco com fim de linha LF):
`242e8c90bd104069fb667362187d6e6460a2cbdbdc9c40a5e0563175bb2f1caa`.

### 2026-10-05 — revisão Decision x Virtual: status ativos, fallback da captura, SOLN e reabertura

Revisão pedida antes do commit, com a Decision lida pelo código
(`queries/consulta_faia_farc.sql`, sem alteração).

**Status ativos.** A Decision tem duas listas:

- `#RegrasStatus_DEC` (linhas 222–263), usada pelo motor [8] do
  `Tempo Total Decision` e do `Tempo suspenso`: ativos `Aberto, aguarda
  atendimento`, `Aguarda atendimento`, `Em andamento`, `Reaberto`;
- motor [9.2] do `Tempo de Atendimento` (linhas 3324–3446), que gera
  `Tempo Atendimento Excedido`, `Meta Atendimento` e `FARC`: ativos só os destinos
  `Em andamento` e `Aberto, aguarda atendimento` (comentário do bloco: "Pausa
  status como Agendado, Aguarda atendimento, Em homologacao e Em teste na TI");
  em [9.3], a regra se chama `STATUS_ATIVO_ABERTO_FILA_E_EM_ANDAMENTO`.

`Tsol` = `Tempo de Atendimento`, por isso a Virtual mantém a lista do [9.2].
Medição na Virtual (12 meses, 293 SDMs, posse até a Resolução):

- `Aguarda atendimento`: 292 SDMs, 467:58:43. Desse tempo, 206:21:57 ficam antes
  do Início (fila depois da transferência, já medida no Tini) e 261:36:46
  depois do Início, em 25 SDMs;
- `Reaberto`: existe no cadastro (`REAB`, `hold = 0`) e chega pelo registro `RO`;
  na posse aparece só em 1660920, por 6 segundos;
- com a lista de 4 ativos, Tsol mudaria em 292 SDMs (+467:58:49), Excesso
  Resolução e FARC em 18, e nenhuma `Meta Atendimento`. FARC de 12 meses:
  1354,468167 → 1357,334500. Não aplicado: a Decision não conta esses status no
  Tempo de Atendimento.

**Fallback da captura.** Decision [4]: `COALESCE(1º ST para 'Em andamento' após
a entrada, 1ª atividade após a entrada exceto TR)`; em [7.1], sem nenhum dos
dois, a captura é o início da contagem (Tempo Primeiro Atendimento 0). Portado
com o mesmo critério de posse do Início. Hoje nenhum dos 293 chamados depende
dele (todos têm `Em andamento` na posse). Teste com a captura por status
desligada: os 293 caíram no fallback de atividade; Início e Tini iguais ao
modelo independente em 293/293.

**Linha de status: RO, CL e SOLN.** A revisão achou transições que a Virtual não
lia. O SDM grava `Status alterado de` também em `RO` (reabertura) e `CL`, e o
`SOLN` muda o status sem gravar a transição. Em 1660920, o `SOLN` de
01/12/2025 18:03:15 encerrou o chamado, que foi reaberto (`RO`,
`Resolvido, concluído` → `Reaberto`) em 02/12 19:17:32. A Virtual contava as
25:14:23 entre um e outro como `Em andamento`. Agora toda transição textual
entra na linha de status, e o `SOLN` entra como passagem para status não ativo,
como na Decision [8.2].

Efeito (contra o estado anterior desta mesma rodada):

| SDM | Tsol | Excesso Resolução | Indice FARC |
|---|---|---|---|
| 1660920 | 360:26:46 → 335:12:23 | 96:26:46 → 83:12:23 | 19,289222 → 16,641278 |
| 1644896 | 244:08:52 → 244:06:02 | 16:08:52 → 16:06:02 | 3,229556 → 3,220111 |
| 1645103 | 237:10:23 → 237:10:18 | 9:10:23 → 9:10:18 | 1,834611 → 1,834333 |
| 1647146 | 73:33:43 → 73:33:38 | 49:33:43 → 49:33:38 | 19,824778 → 19,824222 |
| 1646289, 1646977, 1647203, 1648168 | −4 a −16 s | sem excesso | 0 |

Os 7 casos menores têm `SOLN` segundos antes da `resolve_date`. Nenhum Início,
Tini, FAIA ou meta mudou. A população é a mesma nos dois modos, em todas as
janelas.

Totais de 12 meses (contra `52b9b93`):

| Indicador | Antes | Depois |
|---|---|---|
| FAIA | 0 | 15,559667 |
| FARC `FECHAMENTO` | 1421,059834 | 1302,646278 |
| FARC `RESOLUCAO` | 1870,107834 | 1354,468167 |

Validação:

- modelo Python independente = SQL em Início, Tini, Tsol e Tempo suspenso
  (293/293);
- `Tsol + Tempo suspenso` = posse até a Resolução (293/293);
- os dois modos dão os mesmos valores;
- Power BI x referência sem diferença.

O SHA `242e8c90…` registrado na intervenção anterior foi um estado intermediário
desta rodada, sem commit.

SHA256 do motor (bloco com fim de linha LF):
`265dcbd07712839dff5b426f2a6e05bc3c8acfef55e91ac936cc8625b5c09519`.

### 2026-10-06 — Tempo suspenso, Indicador de Agendamento e Indicador Reabertura

Auditoria antes da mudança (estado `0006366`):

- `Tempo suspenso` já existia (coluna 31): posse até a Resolução − `Tsol`.
  Mantido sem alteração; identidade `posse = Tsol + Tempo suspenso` com 0
  divergências em 293 chamados (12 meses).
- `Indicador Reabertura` já existia (coluna 33), byte a byte igual à Decision
  ([6] `#Reabertura_DEC` e coluna `[Indicador Reabertura]`): `Sim` se algum
  `act_log` do chamado, em todo o histórico, tem tipo contendo `reab` ou
  descrição/ação contendo `reabert`. Mantido: nome (compatível com o Power BI e
  com a Decision), valores e regra. Na população de 12 meses, só 1660920 é
  `Sim`, e é o único com evento `RO` (reabertura real).
- Não havia indicador de agendamento na Virtual nem na Decision.

Limitação conhecida da regra de reabertura (comum à Decision, sem efeito na
população atual): no SDM inteiro desde 2025, 421 chamados têm `RO` e casam com o
texto, 39 têm `RO` e não casam (reabertura direta `Resolvido, concluído` →
`Em andamento`, e `RO` de instanciação de template `Template definido` →
`Aguarda atendimento`), e 239 casam com o texto sem `RO` (reabertura gravada como
`ST` `Em homologação pelo fiscal` → `Reaberto`, mas também comentários com a
palavra "reaberto"). Uma regra pelo evento real (destino `Reaberto` ou `RO`
saindo de status resolvido) seria mais precisa, mas mudaria o conceito em relação
à Decision; ficou para decisão.

Nova coluna 39, `Indicador de Agendamento` (`Sim`/`Não`): transição com destino
`Agendado` (código `AGENDADO`), em qualquer registro de status do `act_log`,
dentro da posse da Virtual, com o mesmo critério de posse do Início. Em 12
meses: 19 `Sim`, 274 `Não`; conferido com modelo independente (19/19). Fora do
indicador por critério: 1731978 (o COI agendou no mesmo segundo da
transferência) e 1731379/1732031 (chegaram já agendados pelo COI e a Virtual não
agendou de novo); o tempo deles em `Agendado` na posse continua em `Tempo
suspenso`.

Validação contra `0006366`, rodando as duas versões no mesmo dia:

- população idêntica em maio, 30/09–06/10 e 12 meses, nos dois modos e nos dois
  regimes;
- 0 diferenças nas 38 colunas anteriores;
- os dois modos dão os mesmos valores;
- Power BI x referência sem diferença nas 39 colunas.

SHA256 do motor (bloco com fim de linha LF):
`2dcbcbbe785ec1f45c47eae9fc4dfec022ff6fe52430d9983a9b3132e32edf9a`.

### 2026-10-06 — Data de Encerramento Virtual e revisão do Tempo suspenso

**Decision (lida no código, sem alteração).**

- `[Data de Encerramento Decision]` vem de `#Encerramento_DEC` ([8.3]): última
  ENTRADA em `Em homologação` (destino com `eh_homologacao_decision = 1`, evento
  anterior não homologação) dentro de uma janela de posse
  (`[inicio, fim)`, ou igual ao fim quando ele é o `close_date`). Os eventos vêm
  de `#StatusEventos_DEC` ([8.2]: `ST`, `CL` textual, `NOVO`, `SOLN` como entrada
  implícita em homologação, `LOG` na exceção de relatórios). Com reabertura, vale
  a última. Fallback [8.3.1], só quando o primário é NULL: último `RE` com
  destino `Em homologação` na posse.
- `[Tempo suspenso]` vem de `#SuspTotal_DEC` ([8.8]): união dos intervalos de
  posse em status fora dos 4 ativos de `#RegrasStatus_DEC` com o par
  `SOLN` → `SRVY_SENT`. A linha do tempo vai da abertura ao `close_date`
  ([8.0]); é corrido; a hora não comercial em status ativo fica no terceiro
  componente (fora da apuração), não no suspenso.

**Virtual.** Nova coluna 40, `Data de Encerramento Virtual` (bloco [6.3]): mesma
regra de entrada e de "última", com os eventos de status já lidos pela linha do
tempo (`ST`, `RE`, `RO`, `CL`) e o critério de posse do Início. Não se adotou o
`SOLN` como entrada implícita: na Virtual o `SOLN` encerra o chamado
(1660920: o `RO` seguinte parte de `Resolvido, concluído`), e a tarefa vetou
substitutos sem evidência. Como o `RE` já é lido como evento de status, o
fallback [8.3.1] da Decision não é necessário.

Medição (12 meses, 293 chamados): 273 com Data de Encerramento Virtual igual à
`Data/Hora Resolução`, 13 com 1 s de diferença (o `resolve_date` gravado 1 s
antes do `RE`), 7 só com resolução (encerrados por `SOLN`, sem homologação:
1644896, 1645103, 1646289, 1646977, 1647146, 1647203, 1648168), 0 só com
homologação. Uma única reabertura com nova homologação (1650824, vale 17:13:55).
Nenhuma entrada em homologação fora da posse em todo o histórico da Virtual (289
entradas em 288 chamados abertos desde 2025). Os critérios de posse do Início,
de janela fechada e da Decision dão o mesmo resultado nos 293.

`Tempo suspenso` revisado e mantido: identidade `posse = Tsol + Tempo suspenso`
com 0 divergências; nenhum valor mudou. As diferenças para a Decision
(terminal na Resolução, e não no `close_date`; `Aguarda atendimento` e
`Reaberto` como pausa) são intencionais e já estavam registradas.

Validação contra `f57148d`, rodando as duas versões no mesmo dia:

- população idêntica nos dois modos e nos dois regimes;
- 0 diferenças nas 39 colunas anteriores;
- nova coluna conferida com modelo independente (293/293);
- Power BI x referência sem diferença nas 40 colunas.

SHA256 do motor (bloco com fim de linha LF):
`4613209919b58701f57654410a51deae60c84bc5be47b4899ac1de875bd59caa`.

### 2026-10-06 — Data de Encerramento Virtual: SOLN como encerramento

Revisão da regra da intervenção anterior, antes do commit. A primeira versão
não aceitava `SOLN` e deixava NULL 7 chamados com `Data/Hora Resolução`.

**Decision (código, sem alteração).**

| Fonte | Como entra |
|---|---|
| `ST`, `CL` | em `#StatusEventos_DEC` ([8.2], `WHERE al.type IN ('ST', 'CL')`) |
| `SOLN` | em `#MarcosSolucao_DEC` (L1997–2068); depois em `#StatusEventos_DEC` com destino `Em homologação`, `eh_homologacao_destino = 1` (L2070–2097), salvo se já houver homologação no mesmo segundo |
| `RE` | só no fallback [8.3.1] (`#EncerramentoRE_DEC`, L2182+), quando `#Encerramento_DEC` é NULL |

- **Escolha** ([8.3], `#Encerramento_DEC`, L2100–2176): entrada = destino de
  homologação com `LAG(eh_homologacao_destino)` = 0, na posse (`[inicio, fim)`);
  vence a última (`ROW_NUMBER` por `evento_epoch DESC`, desempate ST, NOVO, LOG,
  SOLN). A saída é `COALESCE(primário, RE)` (L3101).
- **Limite do modelo da Decision:** como o `RE` não é lido no primário, num
  chamado `SOLN → reabertura → RE` o `SOLN` venceria.

**Virtual.** O bloco [6.3] passa a aceitar, como encerramento, o evento de
status com destino `Em homologação` **ou** o `SOLN`. Vale só a entrada (evento
anterior que não seja encerramento) dentro da posse (critério do Início), e
vence o último. O `RE` é lido como evento de status desde a abertura; por isso a
homologação depois de uma reabertura vence o `SOLN` anterior. A exceção `LOG` da
Decision (Produção de relatórios) não se aplica: nenhum chamado da Virtual tem
essa categoria ou resumo.

**Efeito (12 meses, 293 chamados).** Mudaram só os 7 encerrados por `SOLN` sem
homologação, de NULL para a data do `SOLN`, de 4 a 170 s antes do
`resolve_date`:

| SDM | `SOLN` | `resolve_date` |
|---|---|---|
| 1644896 | 14:22:51 | 14:25:41 |
| 1645103 | 14:26:11 | 14:26:16 |
| 1646289 | 14:26:44 | 14:26:49 |
| 1646977 | 14:28:05 | 14:28:09 |
| 1647146 | 14:30:33 | 14:30:38 |
| 1647203 | 15:59:07 | 15:59:23 |
| 1648168 | 11:18:12 | 11:18:24 |

Todos os 7 têm data de 06/10/2025, exceto 1648168, de 08/10/2025.

- 1660920 continua em 16/12/2025 11:08:09 (`RE` após a reabertura), e não no
  `SOLN` de 01/12.
- 1681392 continua em 11:31:07 (o `SOLN` das 14:47:36 veio com o chamado já em
  homologação).
- Nenhum chamado fica NULL.

Validação contra `f57148d`:

- população idêntica;
- 0 diferenças nas 39 colunas anteriores, incluindo o `Tempo suspenso`;
- modelo independente = SQL (293/293);
- Power BI x referência sem diferença.

SHA256 do motor (bloco com fim de linha LF):
`a2e051688d76dc401d351386685251fe9a17b1c27813b9c717e44c306c927f83`.

### 2026-10-06 — orientação do gerente: `Reaberto` conta e escopo pelo grupo no fechamento

Esta decisão é posterior e prevalece sobre as anteriores nos pontos abaixo.

**Reaberto conta como atendimento.** Orientação do gerente sobre o SDM 1710057
(Decision): analistas encerram por engano como `Resolvido, concluído` quando
deveriam ir para `Em homologação`; o correto é reabrir e pôr o status certo,
e "conta o tempo sim". Fica superada a decisão de 2026-10-05 que deixava
`Reaberto` fora do `Tsol`. Na Virtual, `REAB` passou a ser ativo na linha de
status ([9]), dentro da posse. Efeito em 12 meses: só 1660920 tem `Reaberto` na
posse antes da Resolução (6 s, 02/12/2025 19:17:32–19:17:38): Tsol
335:12:23 → 335:12:29, Tempo suspenso 25:17:20 → 25:17:14, Indice FARC
16,641278 → 16,641611. Nenhum outro valor mudou; `Tini` e o `Indicador
Reabertura` não mudaram.

**Escopo de FECHAMENTO pelo grupo no fechamento.** Orientação do gerente sobre
1651174: a resolução foi feita pelo COI (Lucas dos Santos do Amaral) e "pode
considerar do COI". Auditoria:

- 1651174 nunca entrou no `FECHAMENTO` da Virtual: fechou em 24/07/2026 no COI
  (transferência Virtual → COI em 20/07 15:49:23). A linha com `Grupo = COI`
  vinha do modo `RESOLUCAO`, em que a coluna mostrava o grupo atual.
- Em todo o histórico (fechamentos de 01/01/2025 a 06/10/2026 de chamados que
  passaram pela Virtual), 276 chamados tinham grupo no fechamento = Virtual e
  9 tinham outro grupo (1644738, 1648369, 1651174, 1694191, 1731981, 1732058,
  1732136, 1732146, 1735108, todos fechados no COI). O critério antigo (grupo
  atual + cadeia de transferências) e o histórico concordam nos 285; não há
  transferência no mesmo segundo do fechamento.

Mudança: o pré-filtro de `FECHAMENTO` deixou de exigir o grupo atual (passa a
aceitar quem teve transferência para a Virtual, como o `RESOLUCAO`); a decisão
é só pela cadeia de transferências até o fechamento, com desempate pelo
`act_log.id` do `CL` no mesmo segundo. População idêntica. A consulta com
`FECHAMENTO` fica mais lenta (lê o `act_log` dos fechados do período).

`Grupo` passa a ser derivado do histórico: grupo no fechamento (`FECHAMENTO`,
sempre `Fornecedores - Virtual`) ou na resolução (`RESOLUCAO`). Em 12 meses, só
1651174 muda (de `COI`, grupo atual, para `Fornecedores - Virtual`, grupo no
instante da resolução).

Pendente de decisão, sem alteração: no modo `RESOLUCAO`, 1651174 continua,
porque pelo SDM a resolução (20/07 11:19:27) foi gravada com o chamado no grupo
Virtual. Quem a registrou foi um analista do COI. Excluí-lo exigiria atribuir a
resolução por quem a executou, e não pelo grupo, o que seria uma regra nova.

Validação contra `7619f4c` (mesmo dia):

- população idêntica em todas as janelas e modos;
- `FECHAMENTO` 12 meses com `Grupo <> Virtual` = 0;
- modelo independente = SQL (293/293);
- os dois modos dão os mesmos valores;
- Power BI x referência sem diferença.

SHA256 do motor (bloco com fim de linha LF):
`32f40fec57ef140c3df5cce7f2c62e15582d75361a2cc79a99d7d2e03bb77484`.

### 2026-10-06 — linha de status lê `description` e `action_desc`

A linha de status lia só `description`. No SDM, parte dos registros de status
traz o comentário do analista em `description` e a transição só em
`action_desc`: na população publicada da A2B, 5 reaberturas (`RO`) e 1 `ST`; na
da Decision, 29 `RE` e 73 `CL`. Na Virtual, esses registros seriam perdidos.

Correção no bloco [4]: o texto de status vem de `description` ou, se ela não
trouxer a transição, de `action_desc`, e só para registros de status do chamado
(`ST`, `RE`, `RO`, `CL`, `CLREQ`). Assim nenhum texto arbitrário vira status, e
um `REL_TICKET` (status de mudança relacionada) continua fora.

Impacto atual: nenhum. Os 1.690 registros de status da população publicada
trazem a transição nos dois campos; Power BI e referência sem diferença.

SHA256 do motor (bloco com fim de linha LF):
`b53862ecf92e6f5703ed953ead8506dadad9a78f01296b3e1db41f4341bd228d`.

### 2026-10-06 — avaliação dos status `hold = 0`

Critério (decisão do usuário): um status com `cr_stat.hold = 0` que hoje não
conta só entra na lista de ativos se, em todos os projetos onde ocorrer:

1. aumentar o tempo agregado em até 2%;
2. aumentar o FARC agregado em até 1%;
3. não levar nenhum chamado de Atende para Não Atende;
4. não acrescentar mais de 4 h a nenhum chamado;
5. não mudar a população;
6. não for terminal, administrativo, de problema/mudança nem de outra entidade;
7. representar uma condição operacional do chamado.

A lista continua explícita, e não o `hold` dinâmico.

| Status (`hold = 0`) | Resultado | Motivo |
|---|---|---|
| `Em andamento`, `Aberto, aguarda atendimento`, `Reaberto` | já contam | — |
| `Aguarda atendimento` (`REOP`) | **reprovado** | ver abaixo |
| `Homologada pelo cliente`, `Encerrado`, `Resolvido, avisar cliente`, `Não resolvido, avisar cliente`, `Resolvido pelo VA` e demais terminais/administrativos | reprovado (critério 6) | não são atendimento; nascem depois da resolução |
| status de problema/mudança e de RDM (`REL_TICKET`) | reprovado (critério 6) | outra entidade |
| `Em Progresso`, `Pesquisando`, `Confirmada`, `Aberto pelo VA` | sem evidência para aprovar | não ocorrem nas populações |

`Aguarda atendimento`, contra a versão publicada `4b34195`:

| Projeto | Tempo | FARC | Atende → Não Atende | Maior delta |
|---|---|---|---|---|
| Virtual | +1,76% (`FECHAMENTO`) / +2,00% (`RESOLUCAO`) | +0,22% | 0 | **+115:17 (1647183)** |
| Decision | +1,14% | **+11,98%** | **1** | **+56:04** |
| A2B | **+17,05%** | **+238,5%** | **12** | **+40:39** |

Na Virtual, 206 h das 468 h em `Aguarda atendimento` são fila antes do primeiro
atendimento (289 chamados), já cobrada no `Tini`/FAIA. Nenhum outro status
`hold = 0` do chamado ocorre nas populações. Lista de ativos mantida: `FIP`,
`OP`, `REAB`.

### 2026-10-07 — consulta única com `Tipo SLA` e colunas no padrão da Decision

Pedido: uma só consulta/tabela da Virtual no Power BI, com uma coluna de regime
de SLA, e as colunas informativas da Decision (Categoria, Resumo, Responsável
Abertura, Responsável Atendimento, Responsável Resolução, Severidade, Status,
Meta Primeiro Atendimento, Meta Atendimento).

Regime. O bloco [1] tem um único regime por Tipo + Prioridade (P1/P2 `24x7`,
P3 a P5 `TCU`), e o motor usa esse regime nos dois marcos: `base_resp` e
`base_sol` do bloco [11], e o zero das horas comerciais do bloco [10]. Não há
chamado com início corrido e resolução comercial; uma coluna basta. É a mesma
regra da A2B (P1/P2 corrida, P3-P5 comercial, início e resolução). Nome
escolhido: `Tipo SLA`, com `Corrida` (antigo 24x7) e `Comercial` (antigo TCU);
`N/A` para chamado sem linha de parâmetro (antes caía em `Chamados_TCU` pelo
`ELSE`; nenhum nas populações). `Tipo` sozinho confundiria com
`Tipo (Incidente/Solicitação)`.

Unificação. `Chamados_TCU` e `Chamados_24x7` eram o mesmo arquivo com o filtro
`Aba` invertido; a coluna `Aba` saiu do motor e a saída final virou um
`SELECT` único. Arquivos antigos removidos (sem dois motores paralelos);
`powerbi/consulta_virtual_chamados_power_bi.sql` é o novo. A referência também
passou a devolver um resultado só. SHA256 do motor:
`b24ee071100368f478a5ca23c21325a23df5f9d8f6f400e261438d8b98a20688`.

Colunas (sem duplicar):

| Pedida | Virtual antes | Ação |
|---|---|---|
| Categoria, Status, Responsável Abertura, Responsável Atendimento, Meta Primeiro Atendimento, Meta Atendimento | já existiam, com a definição da Decision | mantidas |
| Resumo | `Descrição do Chamado` (mesmo `call_req.summary`) | renomeada |
| Severidade | `Prioridade` (número) | renomeada, com o rótulo da Decision (`3 - Média`). Na Decision, `TRY_CONVERT(tinyint, pri.sym)` não converte `3 - Média`, e o valor vem de `call_req.priority` 1 a 5, o mesmo campo da Virtual |
| Tipo SLA | `Regime` (`24x7`/`TCU`) | renomeada, com `Corrida`/`Comercial` |
| Responsável Resolução | — | **não criada**: a Decision não tem essa coluna (nem a A2B nem o COI); criar seria inventar a regra |

`chave` ficou como estava (`Incidente|3|TCU`), para não quebrar relação no
PBIX.

Regressão (mesmo instante, consultas antigas x nova):

| Modo | TCU | 24x7 | Em comum | Nova | Duplicados | Diferenças (40 colunas, após o mapeamento de nomes) |
|---|---|---|---|---|---|---|
| FECHAMENTO | 264 | 12 | 0 | 276 | 0 | 0 |
| RESOLUCAO | 281 | 12 | 0 | 293 | 0 | 0 |
| referência maio/2026 | 19 | 0 | 0 | 19 | 0 | 0 |
| referência 01/10/2025 a 07/10/2026 | 264 | 12 | 0 | 276 | 0 | 0 |

24x7 → `Corrida` em 12 de 12; TCU → `Comercial` em 264 de 264 (281 de 281).
Severidade × Tipo SLA: Incidente 1/2 `Corrida` (5/7), Incidente 3 `Comercial`
(18), Solicitação 3/4/5 `Comercial` (230/6/10). As nove colunas pedidas (menos
Responsável Resolução) e `Tipo SLA` estão 100% preenchidas, sem `N/A`. Auditoria
manual de 12 chamados contra `call_req`, `pri`, `cr_stat`, `prob_ctg` e
`ca_contact` (P1 1654284 e 1682345, P2 1647146 e 1667617, P3 1645571 e
1644896, P4 1650824 e 1662379, P5 1647183 e 1655273, reabertura 1660920,
transferência 1646289): tudo confere. PBI = referência na janela de 12 meses.

### 2026-10-07 — feriados fora do SQL (arquivo de feriados)

Motivo: no ambiente controlado do Power BI, qualquer mudança no SQL do
relatório exige pedir nova versão à equipe responsável. Com a lista de
feriados dentro do SQL, um ponto facultativo novo obrigava a republicar. Agora
a lista fica num arquivo (`config/feriados.csv`; no Power BI, o mesmo arquivo
no SharePoint), igual para Virtual, Decision e A2B, com a coluna `Escopo` para
as diferenças entre os projetos. Desenho completo em `docs/feriados.md`.

Arquitetura:

- o SQL Server não lê o SharePoint nem o disco do usuário (a conta não tem
  `ADMINISTER BULK OPERATIONS`, e *Ad Hoc Distributed Queries* está desligado);
  os feriados chegam pelo parâmetro `@Feriados` (JSON). O bloco [2] do motor
  valida e monta `#Virt_Feriado` e `#Virt_FeriadoAnual`; o bloco [8] exclui as
  duas;
- Power BI: `powerbi/consulta_virtual_chamados_power_bi.m` lê o CSV do
  SharePoint, valida, filtra `TODOS`/`VIRTUAL` e chama o SQL por
  `Value.NativeQuery` com o parâmetro. O `.m` é gerado do `.sql`;
- `queries/`: `tools/executar_consulta.ps1` faz o mesmo a partir de
  `config/feriados.csv` (ou gera uma cópia para o SSMS);
- sem `@Feriados`, lista vazia, JSON ou data inválida: erro, nunca zero
  feriados.

Lista: as 42 datas com `Conta_SLA = 'N'` viraram 33 linhas de escopo
`VIRTUAL`/`TODOS` (9 nacionais `MM-DD` e 24 datas). 05/03/2025 (`Conta_SLA = 'S'`)
ficou fora da Virtual; 2025-07-20 (domingo) saiu. Os nacionais passam a valer em
todo ano. A Virtual continua sem 2025-06-20 e 2026-06-29 (a Decision e a A2B têm
2026-06-29, Portaria-TCU nº 93/2026): diferença mantida, registrada em
`docs/feriados.md`.

Regressão (mesmo instante, SQL antigo com a lista embutida x SQL novo com
`@Feriados` do arquivo): referência maio/2026 (19), referência 01/10/2025 a
07/10/2026 (276), Power BI `FECHAMENTO` (276) e `RESOLUCAO` (293): 0 diferenças
nas 40 colunas. A cópia gerada para o SSMS dá o mesmo resultado. Teste de
manutenção: com 2026-09-15 incluído só no arquivo, 2 chamados mudam (1727892:
horas comerciais de resolução 243:24:42 → 231:24:42, um dia útil); retirada a
data, 0 diferenças; o SQL não mudou (mesmo SHA256). SHA256 do motor:
`501d841707082fa0107609620c606361e16c052c9db89466eeb1e056e80fc001`.

### 2026-10-07 — calendário único do TCU e correção do M (Formula.Firewall)

Decisões do usuário (fechadas):

- `Responsável Resolução` **não** é criada na Virtual: a coluna não existe na
  Decision nem existiu no histórico; criá-la exigiria uma regra nova
  (`act_log.analyst` no evento de encerramento seria só uma possível
  definição). A Virtual fica com as oito colunas equivalentes à Decision.
- Virtual, Decision e A2B usam **o mesmo calendário**, o da Portaria do TCU de
  cada ano. Sem diferença por projeto; feriados nacionais fixos recorrentes
  (`MM-DD`); datas móveis e pontos facultativos por ano (`AAAA-MM-DD`).

Fontes: Portarias-TCU nº 10, 67, 157 e 176/2025 e nº 179/2025, 1 e 93/2026,
obtidas do BTCU pela consulta de autenticidade (códigos 77411949, 77981373,
79190602, 79506777, 79561193, 80587034). Arquivo novo: `Data,Descricao,Fonte`,
35 linhas (9 fixas, 13 de 2025, 13 de 2026); coluna `Escopo` removida; tools,
SQL (só comentários) e M sem lógica por projeto.

Efeito na Virtual, contra o estado anterior (`44bc3af`), mesmo instante:

| Consulta | Chamados | Alterados | Colunas | Causa |
|---|---|---|---|---|
| referência maio/2026 | 19 | 0 | — | — |
| Power BI FECHAMENTO / RESOLUCAO | 276 / 293 | 3 / 3 | `Horas Comerciais Resolução (h)` −12:00:00 cada (−36:00:00), `Horas Não Comerciais Resolução (h)` +12:00:00 cada | 29/06/2026 (Portaria-TCU nº 93/2026) |
| referência 01/01/2025 a 07/10/2026, dois modos | 276 / 293 | 3 / 3 | idem | idem |

Maior: 1709362, horas comerciais de resolução 34:07:42 → 22:07:42. Tini,
Tsol, excessos, metas, índices FAIA/FARC e Tempo suspenso não mudam (o Tsol é
tempo corrido; o excesso desses chamados continua igual). Cinzas e 20/06/2025
não afetam a Virtual (não há chamado da Virtual antes de set/2025).

M: a primeira versão gerada falhava com *Formula.Firewall* no motor do Power
BI Desktop, mesmo com SharePoint/Web e SQL como Organizacional (passo final
acessando o SQL com dados de passos que acessavam o Web). O gerador passou a
pôr tudo num único passo `Fonte`. Validado com o motor do Power BI Desktop
(sem PBIX, arquivo por HTTP local): executa com Organizacional +
Organizacional, firewall ativo e sem `FastCombine`; M = SQL (276 linhas, 40
colunas, 0 diferenças); Privado/Público ou nível não definido são recusados;
falhas e casos de borda conferidos. SharePoint Online real, OAuth2, PBIX,
gateway e refresh no serviço ainda dependem do ambiente. SHA256 do motor:
`e94e8bfe4f9d7f4f3c57c7431155a51871de7c64a2f76a968c254f8bca31ea96`.

### 2026-10-07 — revisão contratual de FAIA e FARC (Anexo VII)

> **Substituída em parte** pela correção seletiva logo abaixo: a contagem do
> `Tsol` desde `open_date`, as colunas `Tempo Agendado`/`Tempo Fora Grupo
> Virtual` e os bloqueios (item contratual, suspensão) **não** estão em vigor.
> Continuam valendo as metas, os fatores, a Contagem e os nomes.

Pedido do usuário: usar o Edital PE 90028/2025 e anexos como fonte de verdade,
sem alterar o primeiro atendimento (`Data/Hora Início Atendimento` e
`Tini (h)`), e sem usar Decision/A2B como fonte de regra. Baseline: Virtual
`15dbe62`, Decision `03a6c4f`, A2B `20d50e9`, COI `6eb634d`.

Conferido no PDF original do Anexo VII (autenticidade 77219622): Tabela 1
(metas e cobertura) e Tabela 2 (fatores) iguais aos parâmetros em uso; nada
mudou nelas.

Divergências comprovadas e corrigidas:

| Regra | Antes (herança da Decision / orientação de 2026-10-06) | Agora (contrato) |
|---|---|---|
| Tsol (FARC) | posse da Virtual ∩ status ativos (`FIP`, `OP`, `REAB`); demais status e `SOLN` pausavam | T0 (`open_date`) → T2 sem homologação (`EMHOM`, `CQ`) — 3.1.8 |
| `Aguarda atendimento` (`REOP`) | pausava (decisão de 2026-10-05 pelo impacto) | conta: o contrato não suspende por status |
| `Agendado` | pausava | conta; suspensão exige anuência do TCU (3.4.4, 3.6.1), não registrada no SDM; sai em `Tempo Agendado` |
| Tempo fora do grupo Virtual | não contava | conta (T0 = registro, 3.1.6); sai em `Tempo Fora Grupo Virtual` |
| Reabertura | `Reaberto` contava por orientação do gerente | conta por 3.7.5/3.8.3 (prazo desde a abertura original); o tempo entre solução e reabertura também |

Renomeações: `Tipo SLA` → `Contagem` (`Corrida` → `24x7`, `Comercial` →
`Horário TCU`, decisão do usuário; a "Cobertura" da Tabela 1); `Severidade` →
`Prioridade` (número 1 a 5; a Tabela 4 não rotula a prioridade 5);
`Horas Comerciais`/`Não Comerciais` → `Horas Horário TCU`/`Fora Horário TCU`
(agora com a divisão real também na 24x7); `Tempo suspenso` →
`Tempo Parada Contagem NMS (h)` (6.19.13; só a homologação descontada);
`Meta Atendimento` → `Situação Meta Resolução`; `chave` com `Horário TCU`.
Colunas novas, informativas: `Tempo Agendado (h)` e
`Tempo Fora Grupo Virtual (h)`. Saída com 42 colunas.

Não alterado (documentado em `docs/virtual-calculation.md`, seções 4, 7.4,
7.5, 9, 11 e 12): T1/Tini (congelados; divergem do 3.1.6/3.1.7), FAIA,
população, prioridade gravada na reabertura e na reclassificação (3.2.4 em
aberto), arredondamento (6 casas por chamado; 2 casas no somatório, na
consolidação). **Item contratual n ∈ N: bloqueio funcional** — o SDM não
registra o item e o Anexo IX liga as atividades aos "itens 2 e 3" juntos.

Evidências no SDM (01/2025 a 10/2026, 293 chamados resolvidos): T2
(`resolve_date`) = entrada em `Em homologação` em 286 (±1 s) e `SOLN` em 7;
homologação antes do T2 só em 1650824 e 1647705; 289 registrados fora do grupo
Virtual (mediana 7,5 min até a entrada); 33 com `Agendado`, todos agendados
por terceirizados, com justificativa só em texto livre; trocas de prioridade
(`ESC`) em 12 chamados, nenhuma reclassificação mais rigorosa com novo
chamado.

Validação: `Tsol` igual ao das planilhas NMS do TCU (Resolução − Abertura) em
10/11 (maio/2026), 20/21 (julho/2026) e 24/26 (2025); antes, 0. Recálculo
independente em Python (linha do tempo + feriados) igual ao SQL em 293/293 e
276/276. Referência = Power BI = `.m` no motor do Power BI Desktop: 276 linhas,
42 colunas, 0 diferenças.

Efeito contra `15dbe62`, mesmo instante:

| Consulta | Chamados | `Data/Hora Início Atendimento` / `Tini (h)` | FAIA alterados | FARC alterados | Índice FARC total | Atende → Não Atende |
|---|---|---|---|---|---|---|
| referência maio/2026 (FECHAMENTO) | 19 | 0 / 0 dif. | 0 | 0 | 0 → 0 | 0 |
| 01/2025–10/2026 FECHAMENTO (= Power BI 12 meses) | 276 | 0 / 0 dif. | 0 | 20 | 1302,65 → 1441,69 (+139,04) | 7 |
| 01/2025–10/2026 RESOLUCAO | 293 | 0 / 0 dif. | 0 | 26 | 1354,47 → 1948,75 (+594,28) | 8 |

Maiores: 1651174 (RESOLUCAO; 9 meses em `Agendado`, 9 dias fora da Virtual
antes da entrada) 0 → 408,08; 1650826 0 → 42,38; 1667813 24,58 → 43,37;
1651064 0 → 25,08. Nenhum chamado passou de Não Atende para Atende.

SHA256 do motor (LF): `1bd7e66fffa0efcfec6430fa66608f507f37301a07251125c6a6077ccaa50abe`.

### 2026-10-07 — correção seletiva: restaura o Tempo de Atendimento operacional

Decisão do usuário sobre a revisão contratual acima (commits locais `28c5238`
e `b4c673c`, não publicados): ela foi longe demais ao mudar o `Tsol` para
`T0 (open_date) → T2 − homologação`. O FARC da Virtual **não** deve contar
desde a abertura no SDM, nem o tempo no COI antes da entrada, fora da posse ou
em `Agendado`. Também por decisão do usuário:

- abatimento financeiro por item contratual (itens 2, 3 e 4) está **fora do
  escopo** e não é bloqueio;
- suspensão aprovada pelo TCU não é tratada como bloqueio; nenhum arquivo ou
  mecanismo externo de aceite foi criado;
- reclassificação: vale a prioridade gravada no SDM;
- `Reaberto` continua contando dentro da posse (decisão não reaberta).

Restaurado de `15dbe62` (via `git show`, blocos `[9]` a `[11]` do motor):
status ativos `FIP`/`OP`/`REAB`, `SOLN` como pausa, `Tsol` = posse ∩ status
ativos até a Resolução, parada = posse até a Resolução − `Tsol`. Mantido da
revisão contratual: metas e fatores do Anexo VII (iguais aos de antes),
`Contagem` (`24x7` / `Horário TCU`), `Prioridade` (1 a 5), `Horas Horário TCU`
/ `Fora Horário TCU`, `Situação Meta Resolução`, `chave` com `Horário TCU`,
calendário único e M contra *Formula.Firewall*. `Tempo suspenso` continua com o
nome `Tempo Parada Contagem NMS (h)`, com o conteúdo de `15dbe62`. Saem as
colunas `Tempo Agendado (h)` e `Tempo Fora Grupo Virtual (h)` (eram medidas
sobre o intervalo T0–T2). Saída volta a 40 colunas.

Comparação no mesmo instante (A = `15dbe62`, B = `b4c673c`, C = final):

| Janela | Chamados | `Tsol` A×C | parada A×C | Excessos, metas, FAIA, FARC A×C | T1 A×C | FARC total A / B / C |
|---|---|---|---|---|---|---|
| maio/2026 (FECHAMENTO) | 19 | 0 dif. | 0 dif. | 0 dif. | 0 dif. | 0 / 0 / 0 |
| 01/2025–10/2026 FECHAMENTO | 282 | 0 dif. | 0 dif. | 0 dif. | 0 dif. | 1310,85 / — / 1310,85 |
| 01/2025–10/2026 RESOLUCAO | 293 | 0 dif. | 0 dif. | 0 dif. | 0 dif. | 1354,47 / 1948,75 / 1354,47 |

Única diferença A×C além dos nomes: `Horas Horário TCU` / `Fora Horário TCU`
dos chamados da Contagem `24x7` (9 de 12), que passaram a mostrar a divisão
real em vez de 0 e o total; o excesso 24x7 usa o tempo corrido e não muda.
Referência = Power BI = `.m` (motor do Power BI Desktop): 282 linhas, 40
colunas, 0 diferenças.

Casos: 1651174 (`Tsol` 4:55:25; FARC 0, contra 408,08 em B), 1660920
(335:12:29; 16,64, contra 19,31 em B), 1650826 (7:27:20; 0, contra 42,38),
1667813 (506:53:58; 24,58, contra 43,37), 1704841 (0:53:29; 0), 1719182
(94:09:34; 28,06, contra 28,22 em B).

SHA256 do motor (LF): `94d0ea4f2de32d46a44024daf120c3b2ece597ba685c421b9f112c7db60b792f`.

### 2026-10-07 — verificação final e fonte oficial do Edital

Fonte oficial do pacote de Edital e anexos da contratação PE 90028/2025
(Comprasnet, UASG 30001):
<https://comprasnet.gov.br/ConsultaLicitacoes/download/download_editais_detalhe.asp?coduasg=30001&modprp=5&numprp=900282025>.

Regra contratual usada (Anexo VII): metas por Tipo + Prioridade (Tabela 1),
fatores FAIA 0,4 em todas as prioridades e FARC 0,4 em P1/P2 e 0,2 em P3/P4/P5
(Tabela 2), Contagem 24x7 / Horário TCU (Tabela 1, 3.1.13, 3.1.14) e
terminologia. Conferidas de novo no PDF original: iguais ao bloco `[1]`.

Mecânica operacional preservada (decisão do usuário): Primeiro Atendimento,
Tempo Primeiro Atendimento e Tempo de Atendimento seguem a lógica da Decision
adaptada à posse da Virtual, idêntica à de `15dbe62`; o Tempo de Atendimento
não conta desde `open_date`.

Regressão contra `15dbe62`, mesmo instante (maio/2026 19 chamados;
01/2025–10/2026 FECHAMENTO 282 e RESOLUCAO 293): 0 diferenças em
`Data/Hora Início Atendimento`, `Tini (h)`, `Tsol (h)`, excessos, metas,
`Meta Primeiro Atendimento`, `Situação Meta Resolução`, `Indice FAIA` e
`Indice FARC` (FAIA 15,559667; FARC 1310,850667 / 1354,468500 nos dois modos).
Única diferença além dos nomes: as horas dentro/fora do Horário TCU dos
chamados 24x7 (informativas). SHA256 do motor inalterado:
`94d0ea4f2de32d46a44024daf120c3b2ece597ba685c421b9f112c7db60b792f`.

### 2026-10-07 — calendário de feriados em TXT (`docs/feriados.txt`)

Mudança só de armazenamento do calendário; nenhuma regra de cálculo mudou.
`config/feriados.csv` (`Data,Descricao,Fonte`) foi substituído por
`docs/feriados.txt`: texto simples em seções (`## Regras`,
`## Feriados Fixos` com `DD-MM`, `## Feriados Por Data`,
`## Feriados móveis/diferenciados` e `## Pontos Facultativos` com
`DD-MM-AAAA`), uma data por linha. Gerado por script a partir do CSV, sem
reconstruir datas: 9 fixos, 2 móveis (Paixão de Cristo 2025 e 2026), 24
pontos facultativos (classificados pela própria descrição do CSV), nenhum em
Feriados Por Data. Nomes e Portarias de cada data: parágrafos do arquivo e
tabela de `docs/feriados.md`, seção 2.

Cópias byte a byte idênticas em `docs/feriados.txt` de Decision, A2B, COI e
Virtual e em `Documentos e Relatórios/feriados.txt` (pasta fora do Git, só para
consulta humana); cada repositório lê só a sua cópia.

Leitor (`tools/feriados.ps1`, igual nos três repositórios) e Power Query
(`tools/gerar_powerbi_m.ps1`) com as mesmas regras: só contam linhas que são
apenas `DD-MM` ou `DD-MM-AAAA`; data inexistente, linha que parece data fora do
formato, data repetida, data fora da seção certa, seção desconhecida, arquivo
ausente, vazio ou fora de UTF-8 interrompem com a linha do problema; data com
ano que cai em feriado fixo só gera aviso. As datas continuam indo ao SQL em
`@Feriados` como `MM-DD` / `AAAA-MM-DD`; a `descricao` passou a ser o nome da
seção. SQL: só a linha de comentário que citava o CSV.

Equivalência: mesmas 35 datas normalizadas (PowerShell = M = CSV antigo); de
2025-01-01 a 2027-12-31, 53 datas de feriado/ponto facultativo e 357 dias fora
do Horário TCU antes e depois, 0 perdidas, 0 novas.

Regressão na Virtual (leitor antigo + SQL anterior x leitor novo + SQL atual,
em sequência): referência maio/2026 (19), 01/2025–10/2026 por fechamento (282)
e por resolução (293), Power BI 12 meses (282): 0 diferenças em todas as
colunas, inclusive Primeiro Atendimento, Tempo Primeiro Atendimento, Tempo de
Atendimento, FAIA e FARC. `.m` regenerado e executado no motor do Power BI
Desktop (Organizacional + Organizacional, firewall ativo): M = SQL do Power BI
(282 linhas, 40 colunas). SHA256 do motor (muda só pelo comentário do bloco
`[2]`): `1943c0bf0c13bb9d06607a469de4820ff29001ba4cc5887044d3fcad5735a2fe`.
