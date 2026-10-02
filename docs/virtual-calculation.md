# Apuração FAIA e FARC — Virtual

Regras da consulta [`queries/consulta_virtual_faia_farc.sql`](../queries/consulta_virtual_faia_farc.sql),
que apura FAIA e FARC do fornecedor **Virtual** direto do SDM.

A responsabilidade temporal segue a arquitetura de posse da Decision
(`Extracao_de_dados_Decision`): só conta o tempo em que o chamado esteve no
grupo `Fornecedores - Virtual`. Metas, fatores, regime, calendário e horário
comercial são os da Virtual, vindos das planilhas **Planilha_NMS_TCU**.

---

## Índice

1. [Saída](#1-saída)
2. [Planilhas de origem](#2-planilhas-de-origem)
3. [Escopo e período](#3-escopo-e-período)
4. [DCIM x Manutenção](#4-dcim-x-manutenção)
5. [TCU x 24x7](#5-tcu-x-24x7)
6. [Marcos temporais](#6-marcos-temporais)
7. [Calendário](#7-calendário)
8. [Parâmetros](#8-parâmetros)
9. [Cálculo por chamado](#9-cálculo-por-chamado)
10. [Mapa das colunas](#10-mapa-das-colunas)
11. [Cálculos e Financeiro](#11-cálculos-e-financeiro)
12. [Diferenças em relação às planilhas](#12-diferenças-em-relação-às-planilhas)
13. [Cuidados e limitações](#13-cuidados-e-limitações)

---

## 1. Saída

A consulta devolve **dois resultados**, com as mesmas 37 colunas:

| Resultado | Conteúdo |
|---|---|
| 1 | `Chamados_TCU` |
| 2 | `Chamados_24x7` |

Parâmetros, no topo do arquivo:

| Parâmetro | Significado |
|---|---|
| `@DataInicio` | início do período de **fechamento**, inclusivo, horário do Brasil |
| `@DataFim` | fim do período de fechamento, **exclusivo** |
| `@Planilha` | `N'DCIM'` ou `N'Manutenção'` |

Para um mês inteiro, use o dia 1 do mês e o dia 1 do mês seguinte (por exemplo
`2026-05-01` e `2026-06-01`). Nunca `23:59:59`.

Uma linha por chamado. O motor calcula sempre as duas planilhas e os dois
regimes; `@Planilha` só escolhe o que sai.

As colunas vêm em três blocos (lista completa na seção 10):

| Bloco | Colunas |
|---|---|
| A — identificação e datas | 1 a 9: do `ID Chamado` até `Data/Hora Fechamento` |
| B — apuração da Virtual | 10 a 24: `Tini (h)` até `Indice FAIA` |
| C — contexto no padrão da Decision | 25 a 37: `Status` até `Meta Atendimento` |

## 2. Planilhas de origem

Cada planilha (DCIM e Manutenção) tem seis abas:

| Aba | Papel |
|---|---|
| `Chamados_TCU` | chamados do regime TCU |
| `Chamados_24x7` | chamados do regime 24x7 |
| `Parâmetros` | metas e fatores por Tipo + Prioridade, com o regime e a `chave` |
| `CALENDARIO_TCU` | tabela `tblCalendarioTCU`: feriados e pontos facultativos, com `Conta_SLA` |
| `Cálculos` | totais de FAIA e FARC a partir das duas abas de chamados |
| `Financeiro` | valor mensal, percentual de abatimento e valor a pagar |

As duas planilhas têm a mesma estrutura, a mesma matriz de parâmetros e o mesmo
calendário. O que muda é o conjunto de chamados e o valor mensal contratado.
Delas vêm as 23 colunas originais da apuração, os parâmetros, o calendário e a
separação DCIM x Manutenção. A contagem de tempo segue a seção 9.

## 3. Escopo e período

Um chamado entra na apuração quando:

1. o **fechamento** (`call_req.close_date`) cai em `[@DataInicio, @DataFim)`;
2. é **Incidente** ou **Solicitação** (`type` `I` ou `R`). A matriz de
   parâmetros da Virtual não tem Problema nem Mudança;
3. está em **status terminal**: `CL`, `CLD`, `CLUNRSLV`, `CNCL`, `ATGR`, `END`,
   `PC`, `RE` ou `VARES` (a mesma lista da Decision, lida por código);
4. o **grupo atual** é `Fornecedores - Virtual`;
5. **encerrou na Virtual**: nasceu na Virtual e nunca teve transferência de
   grupo, ou a **última transferência de grupo até o fechamento** foi uma
   entrada na Virtual.

O item 5 é verificado pela cadeia de transferências do `act_log` (`TR`,
`Transferir Grupo de 'X' para 'Y'`), em ordem de `system_time` e `act_log.id`,
e não só pelo grupo atual. Um chamado `COI → Virtual → COI → fechamento` não é
encerramento da Virtual e fica fora.

**Período pelo fechamento.** A abertura pode estar em outro mês:

| Caso | Exemplo | Mês da apuração |
|---|---|---|
| abriu antes, fechou dentro | 1696948: abriu 29/04/2026, fechou 05/05/2026 | maio |
| abriu dentro, fechou depois | 1704841: abriu 28/05/2026, fechou 03/06/2026 | junho |

Chamado ainda sem fechamento não aparece.

**Nasceu na Virtual** quando o grupo de origem da primeira transferência de
grupo é a Virtual; sem nenhuma transferência de grupo, vale o grupo atual. É o
caso, por exemplo, de rotinas registradas pela automação direto na fila.

## 4. DCIM x Manutenção

| Planilha | Regra |
|---|---|
| **DCIM** | chamado **registrado pela automação do SDM** (`call_req.log_agent` = `Usuário de Serviço - ServiceDesk`) **com IC `dcim`** (`call_req.affected_rc`) |
| **Manutenção** | todos os demais chamados do escopo |

O conjunto DCIM são as rotinas agendadas do serviço de DCIM. A mensagem de
criação traz `%AFFECTED_RC=dcim` e `%FROM_USERID=servicedesk`:

- *Checklist Diário — Validação das principais funcionalidades do DCIM*;
- *Rotinas Semanal — Envio consolidado de relatório de Health check do DCIM*;
- *Revisão de documentação do DCIM* (mensal).

A categoria não separa as duas planilhas. A revisão de documentação já foi
registrada como *Climatização*, *Virtual TI.DCIM* e *Elaborar/Manter
Documentação*, e a categoria *Virtual TI.DCIM* também aparece em incidentes de
Manutenção. O IC sozinho também não separa: há chamados manuais com IC `dcim`
na Manutenção. O registrador sozinho também não separa: a análise mensal de
vulnerabilidades (IC `Qualys`) é registrada pela automação e fica na
Manutenção.

A regra separou corretamente os 60 chamados das planilhas conferidas (setembro
e outubro de 2025, maio de 2026, julho de 2026).

## 5. TCU x 24x7

O regime vem da aba **Parâmetros**, pela combinação **Tipo + Prioridade**:

| | P1 | P2 | P3 | P4 | P5 |
|---|---|---|---|---|---|
| Incidente | 24x7 | 24x7 | TCU | TCU | — |
| Solicitação | 24x7 | 24x7 | TCU | TCU | TCU |

O regime não é informado em nenhum campo do SDM. Regime `24x7` vai para o
resultado `Chamados_24x7`; os demais vão para `Chamados_TCU`. A prioridade é a
do chamado no momento da consulta (`call_req.priority`, 1 a 5).

## 6. Marcos temporais

Todos em horário do Brasil (UTC−3), a partir dos campos em epoch do SDM.

| Coluna | Origem |
|---|---|
| `Data/Hora Abertura` | `call_req.open_date` |
| `Data Entrada Grupo Virtual` | primeira entrada na Virtual: a primeira transferência de grupo para `Fornecedores - Virtual`; se nasceu na Virtual, a abertura |
| `Data/Hora Início Atendimento` | primeira **mudança de status** feita **enquanto o chamado está no grupo Virtual** para um status que **não seja de fila** (`Aberto, aguarda atendimento` / `Aguarda atendimento`) |
| `Data/Hora Resolução` | `call_req.resolve_date`, gravado quando o chamado vai para `Em homologação` (evento `RE`) |
| `Data/Hora Fechamento` | `call_req.close_date`, gravado no encerramento do chamado (evento `CL`, em geral pela automação, dias depois da resolução) |

**Início do atendimento.** Ao transferir para a Virtual, o COI devolve o
chamado para `Aguarda atendimento`. O início é o momento em que a fila da
Virtual muda esse status, quase sempre para `Em andamento`, às vezes direto
para `Agendado`. Uma mudança de status só conta se houver uma entrada na
Virtual antes dela e nenhuma saída entre essa entrada e o evento, inclusive no
mesmo segundo.

**Resolução.** Quando `resolve_date` está vazio porque o chamado seguiu para um
status posterior sem marca de resolvido, vale o último evento `RE`, salvo se o
chamado estiver em atendimento aberto. Nos chamados do escopo, `resolve_date`
coincide com a última entrada em `Em homologação` dentro da posse da Virtual,
com no máximo 1 segundo de diferença de gravação.

**Resolução x Fechamento.** São marcos diferentes: a resolução é a entrega da
Virtual; o fechamento é o encerramento do chamado no SDM e define o período.

Exemplo (SDM 1697694):

```text
01/05 09:00:05  INIT  automação                       -> Abertura
01/05 09:13:39  ST    Aberto, aguarda atendimento -> Em andamento   (COI)
01/05 09:21:55  ST    Em andamento -> Aguarda atendimento           (COI)
01/05 09:21:55  TR    Grupo 'COI' -> 'Fornecedores - Virtual'       -> Entrada na Virtual
01/05 09:35:23  ST    Aguarda atendimento -> Em andamento           -> Início
01/05 09:35:24  TR    Responsável '' -> Willian Correa dos Santos   (não muda a posse)
04/05 10:22:01  RE    Em andamento -> Em homologação                -> Resolução
08/05 10:45:39  CL    Em homologação -> Resolvido, concluído        -> Fechamento
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

As **metas** são buscadas por Tipo + Prioridade; os **fatores**, pela `chave`
`Tipo|Prioridade|Regime`. Como o regime vem da mesma linha, as duas buscas
apontam para a mesma linha.

Chamado sem linha de parâmetro (Incidente P5, prioridade não informada) sai em
`Chamados_TCU`, com regime, metas, fatores e índices vazios.

## 9. Cálculo por chamado

### 9.1 Janelas de posse da Virtual

O tempo atribuído à Virtual é a soma das **janelas de posse**:

- o relógio começa na **primeira entrada** na Virtual; se o chamado **nasceu
  na Virtual**, na **abertura**. O tempo em outro grupo antes da entrada não
  conta;
- **saída** da Virtual para o relógio; **reentrada** o religa;
- **todas as janelas são somadas**;
- transferência apenas de **responsável** não muda a posse;
- a resposta é medida até o **Início**, a resolução até a **Resolução**.

As janelas vêm da linha do tempo de grupo: a abertura (no grupo inicial) e
cada transferência de grupo do `act_log`, em ordem de `system_time` e, no
empate, de `act_log.id`. Cada trecho vai de um evento ao seguinte; ficam os
trechos em que o grupo é a Virtual. Eventos no mesmo segundo geram trecho de
duração zero, que não soma nada.

Exemplos:

```text
1714513  COI -> Virtual
  07/07 17:16:48 abertura (COI)
  08/07 16:59:48 entrada na Virtual     janela: 08/07 16:59:48 -> fim
  08/07 17:20:41 Início                 Tini 0:20:53
  o dia em que o chamado ficou no COI não conta

1702424  COI -> Virtual -> COI -> Virtual
  20/05 09:00:02 abertura (COI)
  20/05 09:09:17 entrada -> 09:15:51 saída      janela 1
  20/05 09:18:46 reentrada -> 21/05 10:10:04    janela 2 (até a Resolução)
  Tini 0:24:20; Tsol 24:57:52
```

### 9.2 Colunas

As colunas de duração (as 10 do bloco B e `Tempo suspenso`) saem como **texto
`[h]:mm:ss`**: horas sem limite de
24 (`73:21:56`, `360:00:00`), minutos e segundos com dois dígitos, zero como
`0:00:00`. O cálculo é todo feito em **segundos inteiros**; o texto é montado
só no fim, depois de calculados excessos e índices. Fatores e índices saem como
números e nunca são calculados a partir do texto.

| Coluna | TCU | 24x7 |
|---|---|---|
| `Tini (h)` | tempo corrido nas janelas de posse até o Início | igual |
| `Tsol (h)` | tempo corrido nas janelas de posse até a Resolução | igual |
| `Horas Comerciais Resposta (h)` | parte de Tini dentro de 08:00–20:00, seg–sex, fora das datas `N` | 0 |
| `Horas Não Comerciais Resposta (h)` | Tini − Comerciais Resposta | Tini |
| `Horas Comerciais Resolução (h)` | parte de Tsol dentro da janela comercial | 0 |
| `Horas Não Comerciais Resolução (h)` | Tsol − Comerciais Resolução | Tsol |
| `Meta Resposta (h)` / `Meta Resolução (h)` | parâmetro | parâmetro |
| `Excesso Resposta (h)` | máx(0, Comerciais Resposta − Meta Resposta) | máx(0, Tini − Meta Resposta) |
| `Excesso Resolução (h)` | máx(0, Comerciais Resolução − Meta Resolução) | máx(0, Tsol − Meta Resolução) |
| `Indice FAIA` | Excesso Resposta × Fator FAIA | igual |
| `Indice FARC` | Excesso Resolução × Fator FARC | igual |
| `Meta Primeiro Atendimento` | `Não Atende` se Excesso Resposta > 0; `Atende` se 0; `N/A` sem valor | igual |
| `Meta Atendimento` | o mesmo, sobre Excesso Resolução | igual |

- A janela comercial é calculada dia a dia. Em cada dia útil conta a
  sobreposição do trecho com 08:00–20:00. Sábado e domingo não contam,
  independentemente de `SET DATEFIRST`.
- Dentro da posse, nenhum status suspende a contagem: `Agendado` e outros
  status de espera não são descontados. Por isso `Tempo suspenso` é sempre
  `0:00:00`; a coluna existe para manter o schema alinhado à Decision e não é
  descontada de nenhum tempo, excesso ou índice.
- **Índice** é expresso em **pontos percentuais**: horas de excesso × fator,
  com o excesso em segundos convertido para horas (6 casas). Exemplo: 8,065 h
  de excesso × 0,4 = 3,226. A aba Financeiro divide o total por 100.
- Sem Início, as colunas de resposta ficam vazias.

## 10. Mapa das colunas

| # | Campo final | Origem | Regra |
|---|---|---|---|
| 1 | ID Chamado | `call_req.ref_num` | — |
| 2 | Descrição do Chamado | `call_req.summary` | resumo atual |
| 3 | Tipo (Incidente/Solicitação) | `call_req.type` | I → Incidente, R → Solicitação |
| 4 | Prioridade | `call_req.priority` | 1 a 5 |
| 5 | Regime | Parâmetros | por Tipo + Prioridade; define o resultado |
| 6 | Data/Hora Abertura | `open_date` | seção 6 |
| 7 | Data/Hora Início Atendimento | `act_log` ST/RE dentro da posse | seção 6 |
| 8 | Data/Hora Resolução | `resolve_date` / último RE | seção 6 |
| 9 | **Data/Hora Fechamento** | `close_date` | seção 6; define o período |
| 10 | Tini (h) | janelas de posse até 7 | corrido, `[h]:mm:ss` |
| 11 | Tsol (h) | janelas de posse até 8 | corrido, `[h]:mm:ss` |
| 12 | Horas Comerciais Resposta (h) | parte comercial de 10 | calendário; 24x7 = 0 |
| 13 | Horas Não Comerciais Resposta (h) | 10 − 12 | 24x7 = Tini |
| 14 | Horas Comerciais Resolução (h) | parte comercial de 11 | calendário; 24x7 = 0 |
| 15 | Horas Não Comerciais Resolução (h) | 11 − 14 | 24x7 = Tsol |
| 16 | Meta Resposta (h) | Parâmetros | Tipo + Prioridade |
| 17 | Meta Resolução (h) | Parâmetros | Tipo + Prioridade |
| 18 | Excesso Resposta (h) | 12 (TCU) ou 10 (24x7) − 16 | mín. 0 |
| 19 | Excesso Resolução (h) | 14 (TCU) ou 11 (24x7) − 17 | mín. 0 |
| 20 | chave | 3, 4, 5 | `Tipo\|Prioridade\|Regime` |
| 21 | Fator FARC | Parâmetros | pela chave |
| 22 | Indice FARC | 19 × 21 | pontos percentuais |
| 23 | Fator FAIA | Parâmetros | pela chave |
| 24 | Indice FAIA | 18 × 23 | pontos percentuais |
| 25 | Status | `cr_stat.sym` do status atual | `N/A` sem cadastro |
| 26 | Categoria | `prob_ctg.sym` (área/tipo da solicitação) | `N/A` sem categoria |
| 27 | Responsável Abertura | `call_req.log_agent` → `ca_contact` | nome; senão userid; senão `N/A` |
| 28 | Responsável Atendimento | `call_req.assignee` → `ca_contact` | idem |
| 29 | Item de Configuração | `call_req.affected_rc` → `ca_owned_resource` | vazio sem IC |
| 30 | Data Entrada Grupo Virtual | primeira entrada na Virtual | seção 6 |
| 31 | Tempo suspenso | — | sempre `0:00:00`: a Virtual não tem status que suspendam a contagem |
| 32 | Meta Primeiro Atendimento | 18 | `Atende` / `Não Atende` / `N/A` |
| 33 | Indicador Reabertura | `act_log`: tipo com `reab` ou texto com `reabert` | `Sim` / `Não` |
| 34 | Acordo Prazo | — | `-` (campo reservado, como na Decision) |
| 35 | Acordo Qualidade | — | `-` |
| 36 | Justificativa | — | `-` |
| 37 | Meta Atendimento | 19 | `Atende` / `Não Atende` / `N/A` |

## 11. Cálculos e Financeiro

As duas abas não fazem parte da saída. Elas se reconstroem a partir dos dois
resultados de **cada** planilha:

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
**R$ 22.000,00 na Manutenção**. É um dado do contrato e não entra na consulta.

## 12. Diferenças em relação às planilhas

As planilhas manuais seguem outra regra de tempo e de período. A consulta não as
reproduz nestes pontos:

| Ponto | Planilhas | Consulta |
|---|---|---|
| Início do relógio | abertura do chamado no SDM | primeira entrada na Virtual (ou abertura, se nasceu nela) |
| Tempo fora da Virtual | contado (Abertura → Início e Abertura → Resolução) | não contado (seção 9.1) |
| Período | mês da abertura | mês do fechamento |
| Chamado que voltou ao COI antes de fechar | pode aparecer | fora do escopo |

Pontos em que as planilhas destoam da própria fórmula e que a consulta também não
segue:

| Ponto | Onde aparece | Consulta |
|---|---|---|
| `Horas Comerciais Resolução` da 1ª linha de `Chamados_TCU` da Manutenção é uma constante (0:16:00) | maio/2026 (1698592), julho/2026 (1713847) | calcula pela regra |
| `Indice FAIA` sem `×24` em linhas copiadas (`Q*VALUE(V)`) | DCIM de maio e julho/2026, DCIM e Manutenção de 2025 | horas × fator, como em todo o `Indice FARC` |
| `Horas Comerciais Resposta` do DCIM só trata o mesmo dia | DCIM | conta todos os dias |
| `Horas Comerciais Resposta` da Manutenção ignora `Conta_SLA` | Manutenção | usa `Conta_SLA` |
| Contagem de dias úteis por aproximação semanal | 1647942 (+12 h) | conta dia a dia |
| Regime digitado errado | 1703448 (`s`), 1719182 (`TCU` na aba 24x7) | regime pela tabela |
| Fatores incrementados por arrasto | 1718320, 1720141 (julho/2026) | fatores da tabela |
| Datas digitadas à mão | 1704841, 1716548, 1717462, 1698592, linhas de 2025 | marcos do SDM |
| Descrição de outro chamado | 1704841 (texto de 1647146) | resumo do SDM |
| Fórmulas com vínculo externo `[1]Parâmetros` | 24x7 de maio e julho, DCIM T2/V2 de maio | parâmetros da própria tabela |

## 13. Cuidados e limitações

- **O calendário precisa ser atualizado a cada ano.** Ele cobre 01/01/2025 a
  31/12/2026. As datas ficam no bloco `[2]` do motor, tabela `#Virt_Calendario`,
  em `queries/consulta_virtual_faia_farc.sql`. Inclua as datas do ano novo
  nesse bloco e copie o bloco para os dois arquivos de `powerbi/` (ver
  `docs/powerbi-query.md`, seção 2). Sem isso, os feriados do ano novo não são
  descontados.
- Identidades por UUID: grupo `Fornecedores - Virtual`
  (`0x21679DF702A0EC478B1468D89E769836`), automação `Usuário de Serviço - ServiceDesk`
  (`0xC6BB355348EE414B9EAA9870ADA5C9E5`) e IC `dcim` (`0xA39FE15C43351C41BA9478BA4000BAF5`).
  O nome do grupo é lido do cadastro, porque o `act_log` registra a
  transferência pelo nome.
- Chamados em `Em homologação pelo fiscal` não têm `close_date` e não entram em
  nenhum período enquanto não forem fechados.
