# Apuração FAIA e FARC — Virtual

Regras da consulta [`queries/consulta_virtual_faia_farc.sql`](../queries/consulta_virtual_faia_farc.sql),
que reproduz, direto do SDM, as abas `Chamados_TCU` e `Chamados_24x7` das
planilhas **Planilha_NMS_TCU** da Virtual (DCIM e Manutenção).

---

## Índice

1. [Saída](#1-saída)
2. [Planilhas de origem](#2-planilhas-de-origem)
3. [População](#3-população)
4. [DCIM x Manutenção](#4-dcim-x-manutenção)
5. [TCU x 24x7](#5-tcu-x-24x7)
6. [Marcos temporais](#6-marcos-temporais)
7. [Calendário](#7-calendário)
8. [Parâmetros](#8-parâmetros)
9. [Cálculo por chamado](#9-cálculo-por-chamado)
10. [Mapa das colunas](#10-mapa-das-colunas)
11. [Cálculos e Financeiro](#11-cálculos-e-financeiro)
12. [Pontos das planilhas que a consulta não reproduz](#12-pontos-das-planilhas-que-a-consulta-não-reproduz)
13. [Cuidados e limitações](#13-cuidados-e-limitações)

---

## 1. Saída

A consulta devolve **dois resultados**, com as 23 colunas das abas, na mesma ordem:

| Resultado | Aba da planilha |
|---|---|
| 1 | `Chamados_TCU` |
| 2 | `Chamados_24x7` |

Parâmetros, no topo do arquivo:

| Parâmetro | Significado |
|---|---|
| `@DataInicio` | início do período, inclusivo, horário do Brasil |
| `@DataFim` | fim do período, **exclusivo** |
| `@Planilha` | `N'DCIM'` ou `N'Manutenção'`: qual das duas planilhas é reproduzida |

O período seleciona os chamados pela **data de abertura**. Para um mês inteiro,
use o dia 1 do mês e o dia 1 do mês seguinte (por exemplo `2026-07-01` e
`2026-08-01`). O arquivo vem com `2026-05-01` a `2026-05-31`, o período das
planilhas de maio, nomeadas `01-05-2026 a 30-05-2026`.

Uma linha por chamado. O motor calcula sempre as duas planilhas e os dois
regimes. `@Planilha` só escolhe o que sai.

## 2. Planilhas de origem

Cada planilha (DCIM e Manutenção) tem seis abas:

| Aba | Papel |
|---|---|
| `Chamados_TCU` | chamados do regime TCU: colunas A–H digitadas/coladas, I–W calculadas |
| `Chamados_24x7` | chamados do regime 24x7, mesmas 23 colunas |
| `Parâmetros` | metas e fatores por Tipo + Prioridade, com o regime e a `chave` |
| `CALENDARIO_TCU` | tabela `tblCalendarioTCU`: feriados e pontos facultativos, com `Conta_SLA` |
| `Cálculos` | totais de FAIA e FARC a partir das duas abas de chamados |
| `Financeiro` | valor mensal, percentual de abatimento e valor a pagar |

As duas planilhas têm a mesma estrutura, a mesma matriz de parâmetros e o mesmo
calendário. O que muda é o conjunto de chamados e o valor mensal contratado.

Nas células, os tempos ficam como **fração de dia** (formato `[h]:mm:ss`),
embora os cabeçalhos digam `(h)`. A consulta entrega tudo em **horas decimais**
(seção 9).

## 3. População

Um chamado entra na apuração quando:

1. foi **aberto no período** (`call_req.open_date` dentro de `[@DataInicio, @DataFim)`);
2. é **Incidente** ou **Solicitação** (`type` `I` ou `R`). A matriz de
   parâmetros não tem Problema nem Mudança;
3. **passou pelo grupo `Fornecedores - Virtual`**: nasceu nele ou foi
   transferido para ele em algum momento;
4. não foi encerrado como `Não resolvido, fechado`, `Cancelado` ou `Cancelada`.

O grupo atual não basta. Os chamados da Virtual normalmente nascem no COI e são
transferidos. Vários voltam para o COI depois de resolvidos, ou passam mais de
uma vez pela Virtual. A passagem é lida no `act_log` (`TR`,
`Transferir Grupo de 'X' para 'Fornecedores - Virtual'`).

**Nasceu no grupo** quando o grupo de origem da primeira transferência de grupo
é a Virtual. Isso acontece, por exemplo, com rotinas registradas pela automação
direto na fila. Sem nenhuma transferência de grupo, vale o grupo atual.

**Período.** O chamado pertence ao mês da **abertura**:

- aberto no período e resolvido depois do fim dele: **entra**, com a resolução
  real. Se fosse excluído, nunca seria apurado, porque o mês da resolução
  também não o contém;
- aberto antes do período e resolvido dentro dele: **não entra** (pertence ao
  mês em que foi aberto);
- ainda sem resolução: entra com as colunas de resolução vazias, e os índices de
  resolução só ficam definitivos depois que ele for resolvido.

**Saída da Virtual antes da resolução.** O chamado que passou pela Virtual e
voltou ao COI antes de ser resolvido entra normalmente, com a resolução
registrada no SDM. A contagem não para na saída do grupo.

## 4. DCIM x Manutenção

| Planilha | Regra |
|---|---|
| **DCIM** | chamado **registrado pela automação do SDM** (`call_req.log_agent` = `Usuário de Serviço - ServiceDesk`) **com IC `dcim`** (`call_req.affected_rc`) |
| **Manutenção** | todos os demais chamados da população |

O conjunto DCIM são as rotinas agendadas do serviço de DCIM. A mensagem de
criação traz `%AFFECTED_RC=dcim` e `%FROM_USERID=servicedesk`:

- *Checklist Diário — Validação das principais funcionalidades do DCIM*;
- *Rotinas Semanal — Envio consolidado de relatório de Health check do DCIM*;
- *Revisão de documentação do DCIM* (mensal).

A categoria não separa as duas planilhas. A revisão de documentação já foi
registrada como *Climatização*, *Virtual TI.DCIM* e *Elaborar/Manter
Documentação*, e a categoria *Virtual TI.DCIM* também aparece em incidentes de
Manutenção. O IC sozinho também não separa: há chamados manuais com IC `dcim`
na Manutenção. O mesmo vale para o registrador sozinho: a análise mensal de
vulnerabilidades (IC `Qualys`) também é registrada pela automação e fica na
Manutenção.

A regra separou corretamente os 60 chamados das planilhas conferidas (setembro
e outubro de 2025, maio de 2026, julho de 2026). Em toda a população de 2025–2026,
ela coincide com a marca `%AFFECTED_RC=dcim` da mensagem de criação.

## 5. TCU x 24x7

O regime vem da aba **Parâmetros**, pela combinação **Tipo + Prioridade**:

| | P1 | P2 | P3 | P4 | P5 |
|---|---|---|---|---|---|
| Incidente | 24x7 | 24x7 | TCU | TCU | — |
| Solicitação | 24x7 | 24x7 | TCU | TCU | TCU |

O regime não é informado em nenhum campo do SDM. Nas planilhas ele é digitado na
coluna `Regime`, e o valor digitado sempre corresponde a essa tabela (salvo os
erros de digitação da seção 12). Regime `24x7` vai para `Chamados_24x7`; os
demais vão para `Chamados_TCU`.

A prioridade é a do chamado no momento da consulta (`call_req.priority`, 1 a 5).

## 6. Marcos temporais

Todos em horário do Brasil (UTC−3), a partir dos campos em epoch do SDM.

| Coluna | Origem |
|---|---|
| `Data/Hora Abertura` | `call_req.open_date` |
| `Data/Hora Início Atendimento` | primeira **mudança de status** feita **enquanto o chamado está no grupo Virtual** para um status que **não seja de fila** (`Aberto, aguarda atendimento` / `Aguarda atendimento`) |
| `Data/Hora Resolução` | `call_req.resolve_date`, gravado quando o chamado vai para `Em homologação` (evento `RE`) |

**Início do atendimento.** Ao transferir para a Virtual, o COI devolve o
chamado para `Aguarda atendimento`. O início é o momento em que a fila da
Virtual muda esse status, quase sempre para `Em andamento`, às vezes direto
para `Agendado`. Em geral, o analista da Virtual assume o chamado no mesmo
segundo ou no seguinte.

Uma mudança de status só conta se houver uma entrada na Virtual antes dela e
nenhuma saída da Virtual entre essa entrada e o evento, inclusive no mesmo
segundo. Assim, se o COI retoma o chamado e muda o status no instante em que o
tira da Virtual, essa mudança não conta como início. Quando o chamado nasceu na
Virtual, a entrada é a própria abertura.

**Resolução.** Quando `resolve_date` está vazio porque o chamado seguiu para um
status posterior sem marca de resolvido (`Em homologação pelo fiscal`), vale o
último evento `RE`. Isso não se aplica se o chamado estiver em atendimento
aberto (status sem *hold* e sem marca de resolvido, como `Em andamento`).

Exemplo (SDM 1697694):

```text
01/05 09:00:05  INIT  automação                       -> Abertura
01/05 09:13:39  ST    Aberto, aguarda atendimento -> Em andamento   (COI)
01/05 09:21:55  ST    Em andamento -> Aguarda atendimento           (COI)
01/05 09:21:55  TR    Grupo 'COI' -> 'Fornecedores - Virtual'       (entrada)
01/05 09:35:23  ST    Aguarda atendimento -> Em andamento           -> Início
01/05 09:35:24  TR    Responsável '' -> Willian Correa dos Santos
04/05 10:22:01  RE    Em andamento -> Em homologação                -> Resolução
08/05 10:45:39  CL    Em homologação -> Resolvido, concluído
```

## 7. Calendário

A tabela `CALENDARIO_TCU` (`tblCalendarioTCU`) tem quatro colunas: `Data`,
`Tipo` (Feriado / Facultativo), `Descrição` e `Conta_SLA`.

- `Conta_SLA = 'N'`: a data **não tem horário comercial**.
- Qualquer outro valor: a data conta como dia normal. Na tabela, só 05/03/2025
  (quarta-feira de cinzas) não é `N`.
- Não existe contagem parcial de dia: um dia útil vale das 08:00 às 20:00 inteiro.

A consulta traz as 43 datas da tabela, de 01/01/2025 a 31/12/2026, transcritas
da planilha sem acréscimos. A lista não foi conferida com fonte oficial externa.

## 8. Parâmetros

A aba Parâmetros é idêntica nas duas planilhas. Metas em horas:

| Tipo | Prioridade | Meta Resposta | Meta Resolução | Regime | Fator FAIA | Fator FARC | chave |
|---|---|---|---|---|---|---|---|
| Incidente | 1 | 1h | 12h | 24x7 | 0,4 | 0,4 | `Incidente\|1\|24x7` |
| Incidente | 2 | 2h | 24h | 24x7 | 0,4 | 0,4 | `Incidente\|2\|24x7` |
| Incidente | 3 | 4h | 36h | TCU | 0,4 | 0,2 | `Incidente\|3\|TCU` |
| Incidente | 4 | 8h | 60h | TCU | 0,4 | 0,2 | `Incidente\|4\|TCU` |
| Solicitação | 1 | 15min | 12h | 24x7 | 0,4 | 0,4 | `Solicitação\|1\|24x7` |
| Solicitação | 2 | 2h | 24h | 24x7 | 0,4 | 0,4 | `Solicitação\|2\|24x7` |
| Solicitação | 3 | 4h | 60h | TCU | 0,4 | 0,2 | `Solicitação\|3\|TCU` |
| Solicitação | 4 | 8h | 180h | TCU | 0,4 | 0,2 | `Solicitação\|4\|TCU` |
| Solicitação | 5 | 12h | 360h | TCU | 0,4 | 0,2 | `Solicitação\|5\|TCU` |

Nas abas de chamados, as **metas** são buscadas por Tipo + Prioridade. Os
**fatores** são buscados pela `chave` `Tipo|Prioridade|Regime`. Como o regime
vem da mesma linha de parâmetros, as duas buscas apontam para a mesma linha.

Chamado sem linha de parâmetro (Incidente P5, prioridade não informada) sai em
`Chamados_TCU`, com regime, metas, fatores e índices vazios.

## 9. Cálculo por chamado

Unidade: **horas decimais** em todas as colunas `(h)`. Os tempos são medidos em
segundos e convertidos (`segundos / 3600`). Seis casas decimais.

| Coluna | TCU | 24x7 |
|---|---|---|
| `Tini (h)` | Início − Abertura (tempo corrido; 0 se Início ≤ Abertura) | igual |
| `Tsol (h)` | Resolução − Abertura (tempo corrido; 0 se Resolução ≤ Abertura) | igual |
| `Horas Comerciais Resposta (h)` | horas de Abertura a Início dentro de 08:00–20:00, seg–sex, fora das datas `N` | 0 |
| `Horas Não Comerciais Resposta (h)` | Tini − Comerciais Resposta | Tini |
| `Horas Comerciais Resolução (h)` | horas de Abertura a Resolução dentro da janela comercial | 0 |
| `Horas Não Comerciais Resolução (h)` | Tsol − Comerciais Resolução | Tsol |
| `Meta Resposta (h)` / `Meta Resolução (h)` | parâmetro | parâmetro |
| `Excesso Resposta (h)` | máx(0, Comerciais Resposta − Meta Resposta) | máx(0, Tini − Meta Resposta) |
| `Excesso Resolução (h)` | máx(0, Comerciais Resolução − Meta Resolução) | máx(0, Tsol − Meta Resolução) |
| `Indice FAIA` | Excesso Resposta × Fator FAIA | igual |
| `Indice FARC` | Excesso Resolução × Fator FARC | igual |

- A janela comercial é calculada dia a dia. Em cada dia útil conta a
  sobreposição do intervalo com 08:00–20:00. Sábado e domingo não contam,
  independentemente de `SET DATEFIRST`.
- Nenhum status suspende a contagem: as planilhas medem de Abertura a Início e
  de Abertura a Resolução, sem descontar `Agendado` ou outros status de espera.
- **Índice** é expresso em **pontos percentuais**: horas de excesso × fator.
  Exemplo: 8,065 h de excesso de resposta × 0,4 = 3,226. A aba Financeiro
  divide o total por 100.
- Sem Início, as colunas de resposta ficam vazias. Sem Resolução, as colunas de
  resolução ficam vazias.

## 10. Mapa das colunas

| # | Campo final | Origem | Regra | Parâmetro | TCU x 24x7 |
|---|---|---|---|---|---|
| 1 | ID Chamado | `call_req.ref_num` | — | — | — |
| 2 | Descrição do Chamado | `call_req.summary` | resumo atual | — | — |
| 3 | Tipo (Incidente/Solicitação) | `call_req.type` | I → Incidente, R → Solicitação | — | — |
| 4 | Prioridade | `call_req.priority` | 1 a 5 | — | — |
| 5 | Regime | Parâmetros | por Tipo + Prioridade | Regime | define a aba |
| 6 | Data/Hora Abertura | `open_date` | seção 6 | — | — |
| 7 | Data/Hora Início Atendimento | `act_log` ST/RE + passagens pela Virtual | seção 6 | — | — |
| 8 | Data/Hora Resolução | `resolve_date` / último RE | seção 6 | — | — |
| 9 | Tini (h) | 7 − 6 | corrido | — | igual |
| 10 | Tsol (h) | 8 − 6 | corrido | — | igual |
| 11 | Horas Comerciais Resposta (h) | 6 a 7 | janela comercial | calendário | 24x7 = 0 |
| 12 | Horas Não Comerciais Resposta (h) | 9 − 11 | — | — | 24x7 = Tini |
| 13 | Horas Comerciais Resolução (h) | 6 a 8 | janela comercial | calendário | 24x7 = 0 |
| 14 | Horas Não Comerciais Resolução (h) | 10 − 13 | — | — | 24x7 = Tsol |
| 15 | Meta Resposta (h) | Parâmetros | Tipo + Prioridade | Meta Resposta | — |
| 16 | Meta Resolução (h) | Parâmetros | Tipo + Prioridade | Meta Resolução | — |
| 17 | Excesso Resposta (h) | 11 (TCU) ou 9 (24x7) − 15 | mín. 0 | — | base comercial x corrida |
| 18 | Excesso Resolução (h) | 13 (TCU) ou 10 (24x7) − 16 | mín. 0 | — | base comercial x corrida |
| 19 | chave | 3, 4, 5 | `Tipo\|Prioridade\|Regime` | — | — |
| 20 | Fator FARC | Parâmetros | pela chave | Fator FARC | 24x7 = 0,4; TCU = 0,2 |
| 21 | Indice FARC | 18 × 20 | pontos percentuais | — | — |
| 22 | Fator FAIA | Parâmetros | pela chave | Fator FAIA | 0,4 nos dois |
| 23 | Indice FAIA | 17 × 22 | pontos percentuais | — | — |

## 11. Cálculos e Financeiro

As duas abas não fazem parte da saída. Elas se reconstroem a partir das duas
abas de chamados de **cada** planilha:

| Aba | Linha | Fórmula |
|---|---|---|
| Cálculos | FAIA Total | soma de `Indice FAIA` (TCU + 24x7) |
| Cálculos | FARC Total | soma de `Indice FARC` (TCU + 24x7) |
| Cálculos | FADI Total / FAVR Total | 0 (fixos na planilha) |
| Cálculos | Total | FAIA + FARC + FADI + FAVR, em % |
| Cálculos | Total de Horas | soma de `Excesso Resposta` / `Excesso Resolução` |
| Financeiro | Valor Mensal Contratado | parâmetro financeiro da planilha |
| Financeiro | % Total de Abatimento | Total / 100 |
| Financeiro | Valor Abatido | Valor Mensal × % Total de Abatimento |
| Financeiro | Valor Final a Pagar | Valor Mensal − Valor Abatido |

O valor mensal é diferente em cada planilha: **R$ 16.000,00 no DCIM** e
**R$ 22.000,00 na Manutenção**. É um dado do contrato, fora da regra por
chamado, e por isso não entra na consulta.

## 12. Pontos das planilhas que a consulta não reproduz

A consulta segue a fórmula predominante de cada coluna e os registros do SDM.
Nestes pontos, as planilhas destoam da própria regra:

| Ponto | Onde aparece | Efeito na planilha | Consulta |
|---|---|---|---|
| `Horas Comerciais Resolução` da 1ª linha de `Chamados_TCU` da Manutenção é uma constante (0:16:00), não fórmula | maio/2026 (1698592), julho/2026 (1713847) | horas comerciais de resolução de 16 min | calcula pela regra |
| `Indice FAIA` sem `×24` em linhas copiadas (`Q*VALUE(V)`) | DCIM de maio e julho/2026, DCIM e Manutenção de 2025 | índice 24 vezes menor quando há excesso | `×24` (horas), como na 1ª linha de todas as abas, na Manutenção de 2026 e em todo o `Indice FARC` |
| `Horas Comerciais Resposta` do DCIM só trata abertura e início no mesmo dia | DCIM | resposta que atravessa a noite fica com 0 | conta todos os dias |
| `Horas Comerciais Resposta` da Manutenção exclui **todas** as datas do calendário, ignorando `Conta_SLA` | Manutenção | diferença só em 05/03/2025 | usa `Conta_SLA` |
| Contagem de dias úteis em `Horas Comerciais Resolução` usa aproximação semanal | todas | +12 h quando a resolução cai num domingo e há um sábado entre os dias (1647942) | conta dia a dia |
| Regime digitado errado (`s`; `TCU` em chamado P2 da aba 24x7) | 1703448 (maio), 1719182 (julho) | `chave` sem par nos parâmetros; fatores digitados à mão | regime pela tabela |
| Fatores incrementados por arrasto (1,2 / 1,4 e 2,2 / 2,4) | julho/2026 (1718320, 1720141) | fatores fora da tabela | fatores da tabela |
| Datas digitadas: minutos sem segundos, resolução igual ao início, resolução como texto | 1704841 (maio), 1716548 e 1717462 (julho), linhas de 2025 | tempos diferentes do SDM, `#VALUE!` | marcos do SDM |
| Início digitado como abertura + 5 min | 1698592 (maio) | Tini de 5 min (SDM: 4 min 14 s) | marco do SDM |
| Descrição de outro chamado | 1704841 (maio) | texto de 1647146 | resumo do SDM |
| Fórmulas do 24x7 que apontam para outra pasta (`[1]Parâmetros`, arquivo de março/2026) | 24x7 de maio e julho, DCIM T2/V2 de maio | depende de vínculo externo | parâmetros da própria tabela |

As planilhas de maio/2026 não trazem todos os chamados do período: a de DCIM
termina em 13/05 e a de Manutenção não lista dois incidentes de 15 e 16/05. A
consulta traz os 23 chamados abertos em maio. As planilhas do ciclo 25/09–24/10/2025 usam um calendário com 26/11/2025 no
lugar de 26/12/2025 e, na aba 24x7, a contagem comercial. Os arquivos de 2026
usam o calendário da seção 7 e tempo corrido no 24x7.

## 13. Cuidados e limitações

- **O calendário precisa ser atualizado a cada ano.** Ele cobre 01/01/2025 a
  31/12/2026. As datas ficam no bloco `[2]` do motor, tabela `#Virt_Calendario`,
  em `queries/consulta_virtual_faia_farc.sql`. Inclua as datas do ano novo
  nesse bloco e copie o bloco para os dois arquivos de `powerbi/` (ver
  `docs/powerbi-query.md`, seção 2). Sem isso, os feriados do ano novo não são
  descontados.
- **Índices de chamados em aberto** mudam até a resolução. Uma apuração rodada
  logo no fim do mês pode trazer chamados ainda sem resolução.
- Identidades por UUID: grupo `Fornecedores - Virtual`
  (`0x21679DF702A0EC478B1468D89E769836`), automação `Usuário de Serviço - ServiceDesk`
  (`0xC6BB355348EE414B9EAA9870ADA5C9E5`) e IC `dcim` (`0xA39FE15C43351C41BA9478BA4000BAF5`).
  O nome do grupo é lido do cadastro, porque o `act_log` registra a
  transferência pelo nome.
