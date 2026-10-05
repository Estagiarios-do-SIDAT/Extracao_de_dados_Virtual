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

**Estado vigente:** o motor depende só de dados e regras do SDM. Escopo, posse e
período seguem a arquitetura da Decision; parâmetros e calendário da Virtual
ficam no próprio SQL. Não existe separação DCIM x Manutenção nem parâmetro
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
| Escopo | I/R em status terminal (lista da Decision), grupo atual `Fornecedores - Virtual` e **encerrado na Virtual** (última transferência de grupo até o fechamento foi entrada na Virtual, ou nasceu nela sem transferência) | regra do escopo FAIA da Decision ([3.2] de `consulta_faia_farc.sql`); decisão de 2026-10-02 |
| Período | data escolhida em `@DataReferencia`, semiaberto, sem substituição entre as datas. `FECHAMENTO` (padrão): `close_date`, status terminal, grupo atual e encerramento na Virtual. `RESOLUCAO`: `resolve_date` dentro de uma janela de posse da Virtual, `close_date` opcional | fechamento: regra da Decision ([1] de `consulta_faia_farc.sql`), decisão de 2026-10-02; chave de troca: 2026-10-05 |
| DCIM (removida da arquitetura em 2026-10-02) | `log_agent` = automação (`Usuário de Serviço - ServiceDesk`) **e** IC `dcim` | 60/60; coincide com `%AFFECTED_RC=dcim` da mensagem de criação em toda a população de 2025–2026 (267 chamados) |
| Regime | Parâmetros por Tipo + Prioridade (P1/P2 = 24x7) | nenhum campo do SDM traz o regime |
| Abertura | `open_date` | exato nas linhas não digitadas à mão |
| Início | 1ª mudança de status (ST/RE), dentro de uma passagem pela Virtual, para status fora da fila (`OP`, `REOP`) | exato em todas as linhas não digitadas; 1647942 vai direto para *Agendado* |
| Resolução | `resolve_date`; se vazio, último RE, salvo chamado em atendimento aberto | 1651461 (`Em homologação pelo fiscal` limpa `resolve_date`) |
| Horário comercial | 08–20h, seg–sex, fora das datas com `Conta_SLA = 'N'`, calculado dia a dia | reproduz todas as células K/M com fórmula íntegra |
| 24x7 | comerciais = 0; excesso sobre tempo corrido | planilhas de 2026; FARC real em 1719182 (28,218) |
| Índice FAIA | horas × fator (com ×24) | 1ª linha de todas as abas, FARC inteiro, FAIA real de 1714513 (3,226) |
| Status de espera | não suspendem a contagem | as fórmulas só usam as três datas |
| Posse | relógio começa na 1ª entrada na Virtual (abertura, se nasceu nela); saídas pausam, reentradas reativam, janelas somadas | janelas de posse da Decision ([8.1]); decisão de 2026-10-02 |
| Fechamento | `Data/Hora Fechamento` = `close_date` (= evento CL, ±1 s) | 265 chamados do escopo com CL: 258 no mesmo segundo, 7 com 1 s de diferença de gravação |
| Formato | 10 durações em texto `[h]:mm:ss`; cálculo em segundos; fatores e índices numéricos | igual às planilhas |
| Saída | uma consulta de referência com dois result sets de 38 colunas (blocos A, B, C e a coluna final `Grupo`), um por regime; Power BI em dois arquivos, um por regime, com as mesmas 38 colunas | motor único, bloco idêntico nos três arquivos |

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
