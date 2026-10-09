# Apuração FAIA e FARC — Virtual TI

Regras da consulta [`queries/consulta_virtual_ti_faia_farc.sql`](../queries/consulta_virtual_ti_faia_farc.sql),
que apura FAIA e FARC do fornecedor **Virtual TI** direto do SDM (`mdb`).

Duas fontes, com papéis diferentes:

- **Regra contratual** — Edital PE 90028/2025 e anexos, em especial o
  **Anexo VII — Níveis Mínimos de Serviço** (autenticidade 77219622). Dele vêm
  só: as metas por Tipo + Prioridade, os fatores FAIA e FARC, a cobertura
  (`Contagem`: 24x7 ou Horário TCU) e a terminologia da contratação (seção 13).
- **Mecânica operacional preservada (decisão do usuário)** — três medidas
  **não** seguem a leitura literal dos marcos T0/T1/T2 do Anexo VII (3.1.6 a
  3.1.8) e continuam com a lógica operacional consolidada na Decision
  (`Extracao_de_dados_Decision`) e adaptada à posse da Virtual TI, igual à da
  versão publicada `15dbe62`:
  - `Data/Hora Início Atendimento` (Primeiro Atendimento);
  - `Tini (h)` (Tempo Primeiro Atendimento);
  - `Tsol (h)` (Tempo de Atendimento): posse da Virtual TI em status ativo até a
    resolução. **Não** conta desde a abertura (`open_date`) e **não** inclui o
    tempo antes da entrada na Virtual TI nem fora da posse.

**Fonte oficial do pacote de Edital e anexos** da contratação PE 90028/2025
(Comprasnet, UASG 30001):
<https://comprasnet.gov.br/ConsultaLicitacoes/download/download_editais_detalhe.asp?coduasg=30001&modprp=5&numprp=900282025>. Cópias locais usadas na conferência:
`Documentos e Relatórios/Virtual TI/Edital/` (Edital PE 90028-2025, Anexos I, VII,
VIII, IX, X e XI) e `Documentos e Relatórios/Virtual TI/RelacaoItens03000105900282025000.pdf`.

A população vem só do SDM. Os feriados vêm do calendário
[`docs/feriados.txt`](feriados.txt) (seção 5). A consulta não calcula abatimento financeiro por
item contratual (seção 11).

---

## Índice

1. [Saída](#1-saída)
2. [Escopo e período](#2-escopo-e-período)
3. [Contagem: 24x7 e Horário TCU](#3-contagem-24x7-e-horário-tcu)
4. [Marcos temporais](#4-marcos-temporais)
5. [Calendário](#5-calendário)
6. [Parâmetros](#6-parâmetros)
7. [Cálculo por chamado](#7-cálculo-por-chamado)
8. [Mapa das colunas](#8-mapa-das-colunas)
9. [Totais e arredondamento](#9-totais-e-arredondamento)
10. [Cuidados e limitações](#10-cuidados-e-limitações)
11. [Fora do escopo](#11-fora-do-escopo)
12. [Diferenças conhecidas em relação ao texto do contrato](#12-diferenças-conhecidas-em-relação-ao-texto-do-contrato)
13. [Rastreabilidade](#13-rastreabilidade)

---

## 1. Saída

Uma execução devolve **um resultado**, com 41 colunas: todos os chamados
elegíveis, nas duas Contagens. A coluna `Contagem` diz a janela de contagem de
cada chamado (seção 3). Até 2026-10-06 eram dois resultados, `Chamados_TCU` e
`Chamados_24x7`, com as mesmas colunas.

Parâmetros, no topo do arquivo:

| Parâmetro | Significado |
|---|---|
| `@DataInicio` | início do período, inclusivo, horário do Brasil |
| `@DataFim` | fim do período, **exclusivo** |
| `@DataReferencia` | `N'FECHAMENTO'` (padrão) ou `N'RESOLUCAO'`: data do período e marco em que a responsabilidade da Virtual TI é validada (seção 2) |

Para um mês inteiro, use o dia 1 do mês e o dia 1 do mês seguinte (por exemplo
`2026-05-01` e `2026-06-01`). Nunca `23:59:59`.

Uma linha por chamado. As colunas vêm em blocos (lista completa na seção 8):

| Bloco | Colunas |
|---|---|
| A — identificação e datas | 1 a 9: do `ID Chamado` até `Data/Hora Fechamento` |
| B — apuração | 10 a 24: `Tini (h)` até `Indice FAIA` |
| C — contexto | 25 a 37: `Status` até `Situação Meta Resolução` |
| D — grupo, agendamento, encerramento e tempo total | 38: `Grupo`; 39: `Houve Agendamento`; 40: `Data de Encerramento Virtual TI`; 41: `Tempo Total Virtual TI` |

## 2. Escopo e período

O período e a validação de responsabilidade dependem de `@DataReferencia`,
escolhida em uma linha no topo do arquivo:

| Modo | Data do período | Campo obrigatório | Responsabilidade validada em |
|---|---|---|---|
| `N'FECHAMENTO'` (padrão) | `Data/Hora Fechamento` (`call_req.close_date`) | `close_date` | fechamento: o chamado encerrou na Virtual TI |
| `N'RESOLUCAO'` | `Data/Hora Resolução` (`call_req.resolve_date`) | `resolve_date` (`close_date` pode estar vazio) | instante da resolução: dentro de uma janela de posse da Virtual TI |

Nos dois modos o chamado precisa ser **Incidente** ou **Solicitação** (`type`
`I` ou `R`): o Anexo VII só define níveis de serviço para esses dois tipos
(Tabela 1). Não há substituição entre as datas: se a data do modo estiver
vazia, o chamado não entra. Qualquer outro valor de `@DataReferencia`
interrompe a consulta com o erro *Valor inválido para @DataReferencia. Use
RESOLUCAO ou FECHAMENTO.*

**FECHAMENTO.** O chamado entra quando:

1. `close_date` está preenchido e cai em `[@DataInicio, @DataFim)`;
2. está em **status terminal**: `CL`, `CLD`, `CLUNRSLV`, `CNCL`, `ATGR`, `END`,
   `PC`, `RE` ou `VARES` (a mesma lista da Decision, lida por código);
3. o **grupo no fechamento** é `Fornecedores - Virtual`: nasceu na Virtual TI e
   nunca teve transferência de grupo, ou a **última transferência de grupo até
   o fechamento** foi uma entrada na Virtual TI.

O item 3 é verificado pela cadeia de transferências do `act_log` (`TR`,
`Transferir Grupo de 'X' para 'Y'`), em ordem de `system_time` e `act_log.id`;
o grupo atual do cadastro não decide. Ter passado pela Virtual TI não basta: um
chamado `COI → Virtual TI → COI → fechamento` fechou no COI e fica fora (ex.:
1651174, fechado em 24/07/2026 no COI). Uma transferência gravada no mesmo
segundo do fechamento conta antes dele, salvo se o registro `CL` desse segundo
tiver `act_log.id` menor.

**RESOLUCAO.** O chamado entra quando:

1. `resolve_date` está preenchido e cai em `[@DataInicio, @DataFim)`;
2. passou pela Virtual TI (grupo atual Virtual TI ou alguma transferência de grupo
   para ela);
3. **a resolução ocorreu dentro de uma janela de posse da Virtual TI**:
   `resolve_date` maior ou igual ao início de uma janela e menor ou igual ao
   fim dela; janela ainda aberta vale para qualquer instante posterior ao
   início.

Não se exige fechamento, status terminal nem grupo atual: entra o chamado
resolvido no período e ainda em `Em homologação`, e entra o chamado resolvido
na Virtual TI e depois devolvido ao COI. Um chamado resolvido pelo COI depois de
sair da Virtual TI fica fora.

A chave só muda **quais chamados entram**. Marcos, janelas de posse, tempos,
metas, excessos, índices, Contagem e as colunas de data continuam iguais para
o mesmo chamado nos dois modos. Para chamado ainda não fechado,
`Data/Hora Fechamento` sai vazia e os tempos terminam na resolução, nunca na
data atual.

Exemplos:

| SDM | Resolução | Fechamento | `FECHAMENTO` | `RESOLUCAO` |
|---|---|---|---|---|
| 1697694 | 04/05/2026 | 08/05/2026 | maio | maio |
| 1704841 | 28/05/2026 | 03/06/2026 | junho | maio |
| 1696948 | 29/04/2026 | 05/05/2026 | maio | abril |
| 1736039 | 30/09/2026 | — (em homologação) | não entra | setembro |
| 1651174 | 20/07/2026 (na Virtual TI) | 24/07/2026 (no COI) | não entra | julho |
| 1644738 | 29/09/2025 (pelo COI, após sair da Virtual TI) | 29/09/2025 | não entra | não entra |

**Nasceu na Virtual TI** quando o grupo de origem da primeira transferência de
grupo é a Virtual TI; sem nenhuma transferência de grupo, vale o grupo atual. É o
caso, por exemplo, de rotinas registradas pela automação direto na fila.

## 3. Contagem: 24x7 e Horário TCU

`Contagem` é o nome adotado no relatório para indicar qual janela de contagem
de NMS se aplica ao chamado. **No Anexo VII esse conceito aparece na Tabela 1
como "Cobertura".** Vem dos parâmetros (seção 6), pela combinação
**Tipo + Prioridade**:

| | P1 | P2 | P3 | P4 | P5 |
|---|---|---|---|---|---|
| Incidente | 24x7 | 24x7 | Horário TCU | Horário TCU | — |
| Solicitação | 24x7 | 24x7 | Horário TCU | Horário TCU | Horário TCU |

| `Contagem` | Anexo VII | Janela | Excesso medido sobre |
|---|---|---|---|
| `24x7` | 3.1.14 | 00:00:00–23:59:59, todos os dias, ininterrupto | tempo corrido (`Tini`, `Tsol`) |
| `Horário TCU` | 3.1.13 | 08:00–20:00, segunda a sexta, dias úteis | horas dentro do Horário TCU |
| `N/A` | — | sem linha de parâmetro | sem meta |

- **Uma Contagem por chamado**, a mesma para o primeiro atendimento e para a
  resolução, como na Tabela 1 (uma cobertura por linha).
- A Contagem não está em nenhum campo do SDM. A prioridade é a do chamado no
  momento da consulta (`call_req.priority`, 1 a 5).
- Até 2026-10-07 a coluna se chamava `Tipo SLA`, com os valores `Corrida`
  (24x7) e `Comercial` (Horário TCU), e a `chave` usava `TCU`. Só os nomes
  mudaram: o mesmo chamado tem a mesma janela.

## 4. Marcos temporais

Todos em horário do Brasil (UTC−3), a partir dos campos em epoch do SDM.

| Coluna | Origem |
|---|---|
| `Data/Hora Abertura` | `call_req.open_date` (registro do chamado) |
| `Data Entrada Grupo Virtual TI` | primeira entrada na Virtual TI: a primeira transferência de grupo para `Fornecedores - Virtual`; se nasceu na Virtual TI, a abertura |
| `Data/Hora Início Atendimento` | primeira passagem para **`Em andamento`** (evento `ST`/`RE`) feita **enquanto o chamado está no grupo Virtual TI**: a captura da Decision. Sem ela, a primeira atividade registrada na posse; sem atividade, a entrada na Virtual TI |
| `Data/Hora Resolução` | `call_req.resolve_date`, gravado quando o chamado vai para `Em homologação` (evento `RE`) |
| `Data/Hora Fechamento` | `call_req.close_date`, gravado no encerramento do chamado (evento `CL`, em geral pela automação, dias depois da resolução) |
| `Data de Encerramento Virtual TI` | último **encerramento** da Virtual TI durante a posse: entrada em `Em homologação` ou `SOLN` (ver abaixo); vazia se não houver |

**Primeiro atendimento (congelado).** `Data/Hora Início Atendimento` e
`Tini (h)` (Tempo Primeiro Atendimento) seguem a regra operacional abaixo e não
são alterados por revisões de terminologia ou de parâmetros. Ao transferir para
a Virtual TI, o COI devolve o chamado para `Aguarda atendimento`. O início é a
primeira vez que a Virtual TI põe o chamado em `Em andamento`, como a captura da
Decision. Passar antes para `Agendado` não é início: o chamado ainda não foi
atendido. Um `Em andamento` só conta se houver uma entrada na Virtual TI antes
dele e nenhuma saída entre essa entrada e o evento, inclusive no mesmo segundo;
um `Em andamento` dado pelo COI fora da posse não conta.

Sem `Em andamento` dentro da posse, vale o fallback da Decision:

1. a **primeira atividade** registrada no `act_log` dentro da posse, de
   qualquer tipo exceto transferência (`TR`), com o mesmo critério de posse;
2. sem atividade, a **entrada na Virtual TI** (Tini = 0).

A atividade no mesmo segundo da entrada não conta: é a mudança de status que o
COI grava ao transferir o chamado.

**Resolução.** Quando `resolve_date` está vazio porque o chamado seguiu para um
status posterior sem marca de resolvido, vale o último evento `RE`, salvo se o
chamado estiver em atendimento aberto. Nos chamados do escopo, `resolve_date`
coincide com a última entrada em `Em homologação` (286 de 293 chamados
resolvidos de 01/2025 a 10/2026, ±1 s); nos outros 7, com o registro da
solução (`SOLN`).

**Grupo.** A coluna `Grupo` é o grupo do chamado no instante de referência,
pela linha do tempo de transferências de grupo:

- `FECHAMENTO`: o grupo no fechamento, o mesmo que decide o escopo; como o
  escopo exige a Virtual TI, todas as linhas trazem `Fornecedores - Virtual`;
- `RESOLUCAO`: o grupo no instante da resolução (última transferência de
  grupo antes de `resolve_date`). Um chamado resolvido na Virtual TI e transferido
  depois traz `Fornecedores - Virtual` (ex.: 1651174, resolvido em 20/07/2026
  11:19:27 e transferido ao COI às 15:49:23).

**Data de Encerramento Virtual TI.** O momento em que a Virtual TI encerrou sua
atuação no chamado (equivalente da Data de Encerramento Decision):

- encerra a atuação um evento de status do `act_log` (`ST`, `RE`, `RO`, `CL`...)
  com **destino** `Em homologação` (código `EMHOM`), ou um `SOLN` (solução
  registrada), que a Decision trata como entrada implícita em homologação;
- vale só a **entrada**: o evento anterior na linha do tempo não pode ser
  outro encerramento. `Em homologação` → `Reaberto` não é encerramento, e
  `Em homologação pelo fiscal` é outro status. Um `SOLN` registrado com o
  chamado já em homologação não é novo encerramento (ex.: 1681392);
- o evento precisa estar dentro da posse da Virtual TI, com o mesmo critério do
  Início;
- com reabertura e nova homologação, vale a **última** entrada válida (ex.:
  1650824 → 07/11/2025 17:13:55; 1660920 → 16/12/2025 11:08:09);
- chamado encerrado só por `SOLN` fica com a data do `SOLN` (ex.: 1644896);
- sem evento válido, fica **vazia**.

É informativa: a `Data/Hora Resolução` é o marco dos tempos e do modo
`RESOLUCAO`; a Data de Encerramento Virtual TI não muda população, tempos nem
índices.

Exemplo (SDM 1697694):

```text
01/05 09:00:05  INIT  automação                       -> Abertura
01/05 09:13:39  ST    Aberto, aguarda atendimento -> Em andamento   (COI)
01/05 09:21:55  ST    Em andamento -> Aguarda atendimento           (COI)
01/05 09:21:55  TR    Grupo 'COI' -> 'Fornecedores - Virtual'       -> Entrada na Virtual TI
01/05 09:35:23  ST    Aguarda atendimento -> Em andamento           -> Início
01/05 09:35:24  TR    Responsável '' -> Willian Correa dos Santos   (não muda a posse)
04/05 10:22:01  RE    Em andamento -> Em homologação                -> Resolução
08/05 10:45:39  CL    Em homologação -> Resolvido, concluído        -> Fechamento
```

## 5. Calendário

Os feriados e pontos facultativos vêm do calendário
[`docs/feriados.txt`](feriados.txt): o calendário do TCU, o mesmo da Decision
e da A2B. O bloco `[2]` do motor
recebe a lista no parâmetro `@Feriados`, valida cada data e monta
`#Virt_Feriado` (datas únicas, `AAAA-MM-DD`) e `#Virt_FeriadoAnual` (fixos,
`MM-DD`, todo ano). Quem preenche `@Feriados`: `tools/executar_consulta.ps1`
(consulta de referência) e `powerbi/consulta_virtual_ti_power_bi.m`
(Power BI, a partir do SharePoint; ver `powerbi/powerbi-query.md`). Sem `@Feriados`, ou com lista vazia ou
inválida, a consulta para com erro: nunca calcula com zero feriados.

- Uma data do arquivo **não é dia útil**: fica fora do Horário TCU (3.1.13).
  Não existe contagem parcial de dia: um dia útil vale das 08:00 às 20:00
  inteiro.
- Sábado e domingo nunca estão no Horário TCU.
- Hoje o arquivo tem 35 datas: os 9 feriados nacionais fixos (todo ano) e
  13 datas de 2025 e 13 de 2026, das Portarias do TCU.
- Formato, regras de leitura e cadastro de um ano novo:
  `powerbi/powerbi-query.md`, seção 6.

Até 2026-10-06 a lista ficava no próprio SQL (`#Virt_Calendario`, 43 datas de
2025 e 2026, com `Conta_SLA`). Desde 2026-10-07 a Virtual TI usa o calendário
único do TCU.

## 6. Parâmetros

Ficam no bloco `[1]` do motor (`#Virt_Parametros`), transcritos do Anexo VII:
metas e cobertura da **Tabela 1**, fatores da **Tabela 2** (% por hora ou
fração de hora excedida). Conferidos no PDF original em 2026-10-07; são os
mesmos usados desde a primeira versão.

| Tipo | Prioridade | Meta Resposta (primeiro atendimento) | Meta Resolução | Contagem (Cobertura) | Fator FAIA | Fator FARC | Chave |
|---|---|---|---|---|---|---|---|
| Incidente | 1 | 60 min | 12h | 24x7 | 0,4 | 0,4 | `Incidente\|1\|24x7` |
| Incidente | 2 | 2h | 24h | 24x7 | 0,4 | 0,4 | `Incidente\|2\|24x7` |
| Incidente | 3 | 4h | 36h | Horário TCU | 0,4 | 0,2 | `Incidente\|3\|Horário TCU` |
| Incidente | 4 | 8h | 60h | Horário TCU | 0,4 | 0,2 | `Incidente\|4\|Horário TCU` |
| Solicitação | 1 | 15 min | 12h | 24x7 | 0,4 | 0,4 | `Solicitação\|1\|24x7` |
| Solicitação | 2 | 2h | 24h | 24x7 | 0,4 | 0,4 | `Solicitação\|2\|24x7` |
| Solicitação | 3 | 4h | 60h | Horário TCU | 0,4 | 0,2 | `Solicitação\|3\|Horário TCU` |
| Solicitação | 4 | 8h | 180h | Horário TCU | 0,4 | 0,2 | `Solicitação\|4\|Horário TCU` |
| Solicitação | 5 | 12h | 360h | Horário TCU | 0,4 | 0,2 | `Solicitação\|5\|Horário TCU` |

Chamado sem linha de parâmetro (Incidente P5, prioridade não informada) sai com
`Contagem` = `N/A` e metas, fatores e índices vazios. Nenhum chamado das
populações publicadas está nesse caso.

## 7. Cálculo por chamado

### 7.1 Janelas de posse da Virtual TI

O tempo atribuído à Virtual TI é a soma das **janelas de posse**:

- o relógio começa na **primeira entrada** na Virtual TI; se o chamado **nasceu
  na Virtual TI**, na **abertura**. O tempo em outro grupo antes da entrada não
  conta;
- **saída** da Virtual TI para o relógio; **reentrada** o religa;
- **todas as janelas são somadas**;
- transferência apenas de **responsável** não muda a posse;
- o primeiro atendimento é medido até o **Início**, a resolução até a
  **Resolução**.

As janelas vêm da linha do tempo de grupo: a abertura (no grupo inicial) e
cada transferência de grupo do `act_log`, em ordem de `system_time` e, no
empate, de `act_log.id`. Cada trecho vai de um evento ao seguinte; ficam os
trechos em que o grupo é a Virtual TI. Eventos no mesmo segundo geram trecho de
duração zero, que não soma nada.

Exemplos:

```text
1714513  COI -> Virtual TI
  07/07 17:16:48 abertura (COI)
  08/07 16:59:48 entrada na Virtual TI     janela: 08/07 16:59:48 -> fim
  08/07 17:20:41 Início                 Tini 0:20:53
  o dia em que o chamado ficou no COI não conta

1702424  COI -> Virtual TI -> COI -> Virtual TI
  20/05 09:00:02 abertura (COI)
  20/05 09:09:17 entrada -> 09:15:51 saída      janela 1
  20/05 09:18:46 reentrada -> 21/05 10:10:04    janela 2 (até a Resolução)
  Tini 0:24:20 (6:34 da janela 1 + 17:46 da janela 2, até o Início)
  Tsol 24:33:32 (só em Em andamento; os 24:20 em Aguarda atendimento são parada)
```

### 7.2 Tempo de Atendimento (Tsol) e Tempo Parada Contagem NMS

Dentro da posse, o Tempo de Atendimento (`Tsol`) conta só os status
**ativos**:

| Status | Código | Tsol |
|---|---|---|
| `Em andamento` | `FIP` | conta |
| `Aberto, aguarda atendimento` | `OP` | conta |
| `Reaberto` | `REAB` | conta: reabrir corrige um encerramento indevido, e o tempo é de atendimento |
| `Aguarda atendimento`, `Agendado`, `Aguarda fornecedor`, `Em homologação`, `Resolvido, concluído` e os demais | — | pausa; vai para `Tempo Parada Contagem NMS` |

A lista de status ativos é **explícita** (códigos `FIP`, `OP`, `REAB`), e não
o campo `cr_stat.hold`. `Aguarda atendimento` (`REOP`) não conta: a fila antes
do primeiro atendimento já entra no `Tini`/FAIA (decisão de 2026-10-05).

A linha do tempo de status vem dos registros de status do próprio chamado no
`act_log`: `ST` (mudança manual), `RE` (ida para `Em homologação`), `RO`
(reabertura), `CL` (encerramento) e `CLREQ`, com o texto
`Status alterado de 'X' para 'Y'.`. O texto é lido de `description` e, quando
ela traz só o comentário do analista (comum em reaberturas), de `action_desc`.
Outros tipos não viram status do chamado. Os eventos seguem a ordem de
`system_time` e, no empate, de `act_log.id`. Na abertura vale a origem `X` do
primeiro evento (sem evento, `Aberto, aguarda atendimento`); a partir de cada
evento vale o destino `Y`, até o evento seguinte.

Um `SOLN` (solução registrada) muda o status sem gravar a transição. Como na
Decision, ele entra na linha do tempo como passagem para um status não ativo,
que vale até o evento seguinte.

`Tsol` é a interseção, até a Resolução, das janelas de posse com os trechos
ativos, somada em todas as janelas. `Tempo Parada Contagem NMS` é o restante
da posse até a Resolução:

```text
Tsol + Tempo Parada Contagem NMS = tempo de posse até a Resolução = Tempo Total Virtual TI
```

O tempo fora da posse (antes da primeira entrada na Virtual TI e entre uma saída e
uma reentrada) não entra em nenhum dos três.

`Tempo Total Virtual TI` é esse tempo de posse até a Resolução, já somado pelo
motor (`posse_sol_s`, o mesmo valor de onde sai a parada):

- começa na entrada na Virtual TI (ou na abertura, se o chamado nasceu nela);
- soma todas as janelas de posse, em status ativo ou que pausa;
- para nas saídas para outro grupo e volta nas reentradas;
- termina na Resolução: o tempo entre a Resolução e o fechamento não entra.

É o mesmo valor nos modos `FECHAMENTO` e `RESOLUCAO` (o modo só escolhe quais
chamados entram). É informativo: não entra em excesso, índice, FAIA ou FARC.
Não é o intervalo entre a abertura e o fechamento, e não foi conferido como
equivalente ao `Tempo Total Decision`, que segue a mecânica própria da Decision.

Exemplo (SDM 1698592, duas passagens):

```text
05/05 15:25:33 entrada na Virtual TI (Aguarda atendimento)   pausa       0:01:27
05/05 15:27:00 Em andamento -> Início                     Tsol        0:05:10
05/05 15:32:10 saída para o COI                           fora da posse
06/05 16:09:58 reentrada (Aguarda atendimento)            pausa       0:01:42
06/05 16:11:40 Em andamento                               Tsol        2:04:14
06/05 18:15:54 Em homologação -> Resolução
Tini 0:01:27   Tsol 2:09:24   Tempo Parada Contagem NMS 0:03:09
```

Um chamado em `Agendado` por meses dentro da posse (rotinas que a Virtual TI
reagenda) acumula esse tempo em `Tempo Parada Contagem NMS`, e não em `Tsol`.
Exemplo: 1651174 ficou nove meses quase todo em `Agendado`; `Tsol` 4:55:25,
parada 6331:19:38, `Tempo Total Virtual TI` 6336:15:03, FARC 0.

### 7.3 Reabertura

Reabertura entra na linha do tempo de status: o tempo em `Reaberto` dentro da
posse conta no `Tsol`, e o atendimento seguinte também; o relógio termina na
Resolução (a última, depois da reabertura). O tempo entre um `SOLN` e a
reabertura é parada. Exemplo (SDM 1660920): solução em 01/12/2025 18:03:15,
reabertura (`RO`, `Resolvido, concluído` → `Reaberto`) em 02/12 19:17:32 e volta
a `Em andamento` às 19:17:38, resolução em 16/12 11:08:09. As 25:14:17 entre a
solução e a reabertura são parada; os 6 segundos em `Reaberto` e o atendimento
seguinte contam (`Tsol` 335:12:29).

### 7.4 Prioridade

Vale a prioridade gravada no chamado no momento da consulta
(`call_req.priority`). Trocas de prioridade ficam no `act_log` (`ESC`); a
consulta não monta uma linha do tempo de prioridade.

### 7.5 Colunas

As colunas de duração saem como **texto `[h]:mm:ss`**: horas sem limite de 24
(`73:21:56`, `360:00:00`), minutos e segundos com dois dígitos, zero como
`0:00:00`. O cálculo é todo feito em **segundos inteiros**; o texto é montado
só no fim, depois de calculados excessos e índices. Fatores e índices saem como
números e nunca são calculados a partir do texto.

| Coluna | Regra |
|---|---|
| `Tini (h)` | tempo corrido nas janelas de posse até o Início, em qualquer status (congelado) |
| `Tsol (h)` | tempo corrido nas janelas de posse até a Resolução, só em status ativo (7.2) |
| `Horas Horário TCU Resposta (h)` | parte do `Tini` dentro do Horário TCU (seção 5), nas duas Contagens |
| `Horas Fora Horário TCU Resposta (h)` | `Tini` − Horário TCU Resposta |
| `Horas Horário TCU Resolução (h)` | parte do `Tsol` (trechos ativos) dentro do Horário TCU, nas duas Contagens |
| `Horas Fora Horário TCU Resolução (h)` | `Tsol` − Horário TCU Resolução |
| `Meta Resposta (h)` / `Meta Resolução (h)` | Tabela 1 |
| `Excesso Resposta (h)` | Horário TCU: máx(0, Horário TCU Resposta − Meta Resposta); 24x7: máx(0, `Tini` − Meta Resposta) |
| `Excesso Resolução (h)` | Horário TCU: máx(0, Horário TCU Resolução − Meta Resolução); 24x7: máx(0, `Tsol` − Meta Resolução) |
| `Indice FAIA` | Excesso Resposta (horas, 6 casas) × Fator FAIA |
| `Indice FARC` | Excesso Resolução (horas, 6 casas) × Fator FARC |
| `Tempo Parada Contagem NMS (h)` | posse até a Resolução − `Tsol`, corrido (7.2) |
| `Tempo Total Virtual TI` | posse até a Resolução, corrido, em qualquer status = `Tsol` + `Tempo Parada Contagem NMS` (7.2) |
| `Meta Primeiro Atendimento` | `Não Atende` se Excesso Resposta > 0; `Atende` se 0; `N/A` sem valor |
| `Situação Meta Resolução` | o mesmo, sobre Excesso Resolução |

- O Horário TCU é calculado dia a dia: em cada dia útil conta a sobreposição do
  trecho com 08:00–20:00. Sábado, domingo e datas do arquivo de feriados não
  contam, independentemente de `SET DATEFIRST`.
- As horas dentro e fora do Horário TCU são medidas sobre os mesmos trechos do
  tempo de que fazem parte. Valem sempre: `Tini` = Horário TCU Resposta + Fora
  Horário TCU Resposta; `Tsol` = Horário TCU Resolução + Fora Horário TCU
  Resolução.
- Na Contagem `24x7` essas horas são informativas (até 2026-10-07 saíam 0 e o
  total); o excesso usa o tempo corrido.
- `Tempo Parada Contagem NMS` é informativo: já está fora do `Tsol` e não é
  descontado de novo de nenhum excesso ou índice. `Tempo Total Virtual TI`
  também é informativo.
- **Índice** em **pontos percentuais**: 8,065 h de excesso × 0,4 = 3,226.
- Com o fallback da captura (seção 4), todo chamado que entrou na Virtual TI tem
  Início.

Correspondência com as colunas da Decision:

| Virtual TI | Decision |
|---|---|
| `Tini (h)` | Tempo Primeiro Atendimento |
| `Tsol (h)` | Tempo de Atendimento |
| `Excesso Resposta (h)` | Primeiro Atendimento Excedido |
| `Excesso Resolução (h)` | Tempo Atendimento Excedido |

Diferenças em relação à Decision:

| Regra | Decision | Virtual TI | Motivo |
|---|---|---|---|
| Captura | 1º `Em andamento` após a entrada, em qualquer grupo | 1º `Em andamento` dentro da posse | o `Em andamento` dado pelo COI depois de o chamado sair da Virtual TI não é atendimento da Virtual TI |
| Tempo Primeiro Atendimento | intervalo contínuo da entrada à captura | só o tempo de posse até a captura | tempo em outro grupo não é responsabilidade da Virtual TI |
| Passagens no Tempo de Atendimento | a partir da última entrada | todas as janelas de posse | a Virtual TI atende em mais de uma passagem |
| Fim do Tempo de Atendimento | 1º `SOLN`, senão `resolve_date` | Resolução (`resolve_date`), com o `SOLN` como pausa | na Virtual TI a entrega é a ida para `Em homologação`; o `SOLN` é raro e pode ser seguido de reabertura |
| Tempo de parada | posse da abertura ao `close_date`, em status fora dos ativos do `Tempo Total Decision` | posse até a Resolução − `Tsol` | a Virtual TI não tem `Tempo Total Decision`; a parada é o complemento do `Tsol` no mesmo intervalo |
| Tempo total | `Tempo Total Decision` (mecânica própria) | `Tempo Total Virtual TI` = posse até a Resolução | não conferidos como equivalentes; na Virtual TI o intervalo termina na Resolução |

### 7.6 Indicadores

| Coluna | Pergunta | Fonte | Depende da posse? | Valores |
|---|---|---|---|---|
| `Indicador Reabertura` | o chamado foi reaberto? | `act_log` com tipo contendo `reab` ou descrição/ação contendo `reabert`, em todo o histórico do chamado | não | `Sim` / `Não` |
| `Houve Agendamento` | o chamado passou para `Agendado` enquanto estava com a Virtual TI? | registro de status com **destino** `Agendado` (código `AGENDADO`), dentro de uma janela de posse | sim | `Sim` / `Não` |

Os indicadores não mudam tempos, excessos nem índices.

## 8. Mapa das colunas

| # | Campo final | Origem | Regra | Termo do Anexo VII |
|---|---|---|---|---|
| 1 | ID Chamado | `call_req.ref_num` | — | número do chamado (6.19.6) |
| 2 | Resumo | `call_req.summary` | sem espaços nas pontas | breve descrição do chamado (6.19.14) |
| 3 | Tipo (Incidente/Solicitação) | `call_req.type` | I → Incidente, R → Solicitação | tipo (6.19.2) |
| 4 | Prioridade | `call_req.priority` | número e nome: `1 - Máxima`, `2 - Alta`, `3 - Média`, `4 - Baixa`, `5 - Mínima` (fora de 1 a 5: só o número; vazio continua vazio) | prioridade (Tabela 4) |
| 5 | Contagem | parâmetros | `24x7` / `Horário TCU` / `N/A` | cobertura (Tabela 1) |
| 6 | Data/Hora Abertura | `open_date` | seção 4 | registro do chamado |
| 7 | Data/Hora Início Atendimento | `act_log`: 1º `Em andamento` dentro da posse; senão 1ª atividade na posse; senão a entrada | seção 4 (congelado) | — |
| 8 | Data/Hora Resolução | `resolve_date` / último RE | seção 4; define o período com `RESOLUCAO` | resolução |
| 9 | Data/Hora Fechamento | `close_date` | seção 4; define o período com `FECHAMENTO` | encerramento (3.7) |
| 10 | Tini (h) | janelas de posse até 7 | corrido; Tempo Primeiro Atendimento (congelado) | — |
| 11 | Tsol (h) | janelas de posse até 8, só status ativo | corrido; Tempo de Atendimento | Tsol (Equação 4) |
| 12 | Horas Horário TCU Resposta (h) | parte de 10 no Horário TCU | 7.5 | Horário TCU (3.1.13) |
| 13 | Horas Fora Horário TCU Resposta (h) | 10 − 12 | 7.5 | — |
| 14 | Horas Horário TCU Resolução (h) | parte de 11 no Horário TCU | 7.5 | Horário TCU (3.1.13) |
| 15 | Horas Fora Horário TCU Resolução (h) | 11 − 14 | 7.5 | — |
| 16 | Meta Resposta (h) | parâmetros | Tabela 1 | resposta inicial |
| 17 | Meta Resolução (h) | parâmetros | Tabela 1 | resolução |
| 18 | Excesso Resposta (h) | 12 (Horário TCU) ou 10 (24x7) − 16 | mín. 0 | Exc (Equação 1) |
| 19 | Excesso Resolução (h) | 14 (Horário TCU) ou 11 (24x7) − 17 | mín. 0 | Exc (Equação 4); tempo extrapolado |
| 20 | Chave | 3, 4, 5 | `Tipo\|Prioridade\|Contagem`, com a prioridade em número (`Solicitação\|3\|Horário TCU`) | — |
| 21 | Fator FARC | parâmetros | Tabela 2 | fator FARC |
| 22 | Indice FARC | 19 × 21 | pontos percentuais | IndFARC (Equação 5) |
| 23 | Fator FAIA | parâmetros | Tabela 2 | fator FAIA |
| 24 | Indice FAIA | 18 × 23 | pontos percentuais | IndFAIA (Equação 2) |
| 25 | Status | `cr_stat.sym` do status atual | `N/A` sem cadastro | status do chamado (6.19.1) |
| 26 | Categoria | `prob_ctg.sym` | `N/A` sem categoria | categorização (3.1.4) |
| 27 | Responsável Abertura | `call_req.log_agent` → `ca_contact` | nome; senão userid; senão `N/A` | — |
| 28 | Responsável Atendimento | `call_req.assignee` → `ca_contact` | idem | responsável pelo atendimento (6.19.8) |
| 29 | Item de Configuração | `call_req.affected_rc` → `ca_owned_resource` | vazio sem IC | — |
| 30 | Data Entrada Grupo Virtual TI | primeira entrada na Virtual TI | seção 4 | — |
| 31 | Tempo Parada Contagem NMS (h) | janelas de posse até 8 − 11 | corrido; posse em status que pausam (7.2) | tempo total de parada de contagem de NMS (6.19.13) |
| 32 | Meta Primeiro Atendimento | 18 | `Atende` / `Não Atende` / `N/A` | — |
| 33 | Indicador Reabertura | `act_log` | `Sim` / `Não` (7.6) | reabertura (3.8) |
| 34 | Acordo Prazo | — | `-` (campo reservado) | — |
| 35 | Acordo Qualidade | — | `-` | — |
| 36 | Justificativa | — | `-` | — |
| 37 | Situação Meta Resolução | 19 | `Atende` / `Não Atende` / `N/A` | — |
| 38 | Grupo | `act_log` (transferências) | grupo no fechamento ou na resolução | — |
| 39 | Houve Agendamento | `act_log` | `Sim` / `Não` (7.6) | — |
| 40 | Data de Encerramento Virtual TI | `act_log` | informativa (seção 4) | — |
| 41 | Tempo Total Virtual TI | janelas de posse até 8, qualquer status | corrido; = 11 + 31; informativo (7.2) | — |

### 8.1 Nomes revisados em 2026-10-07

Em 2026-10-08 a coluna `Prioridade` passou a trazer o número com o nome (`3` → `3 - Média`), nos mesmos rótulos da `Severidade` da A2B e da Decision. É só apresentação: as metas e os fatores (junção com os parâmetros) e a `Chave` continuam usando o número (`call_req.priority`), e nenhuma outra coluna mudou.

Ainda em 2026-10-08, `Indicador de Agendamento` passou a se chamar `Houve Agendamento` (mesma posição 39, mesma regra e mesmos valores `Sim`/`Não`).

Também em 2026-10-08: `chave` passou a se chamar `Chave` (mesma posição, mesma composição `Tipo|Prioridade|Contagem` e mesmos valores, com a prioridade em número), e entrou a coluna 41, `Tempo Total Virtual TI` (7.2). Nenhuma outra coluna mudou.

| Antes | Depois | Fundamento |
|---|---|---|
| `Tipo SLA` (`Corrida` / `Comercial`) | `Contagem` (`24x7` / `Horário TCU`) | decisão do usuário; Anexo VII Tabela 1 (cobertura), 3.1.13, 3.1.14 |
| `Severidade` (`3 - Média`) | `Prioridade` (`3`) | o contrato usa "prioridade" (3.2, Tabela 4); a Tabela 4 só rotula 1 a 4 (CRÍTICA, ALTA, MÉDIA, BAIXA), por isso sai o número |
| `Horas Comerciais` / `Horas Não Comerciais` | `Horas Horário TCU` / `Horas Fora Horário TCU` | o contrato não usa "horário comercial"; a janela é o Horário TCU (3.1.13) |
| `Tempo suspenso` | `Tempo Parada Contagem NMS (h)` | 6.19.13; mesmo conteúdo |
| `Meta Atendimento` | `Situação Meta Resolução` | a coluna avalia a meta de **resolução** (Tabela 1) |
| `chave` com `TCU` | `chave` com `Horário TCU` | acompanha a Contagem |

Mantidos: `Data/Hora Início Atendimento`, `Tini (h)` (congelados),
`Meta Primeiro Atendimento`, `Tsol (h)`, `Excesso`, `Meta Resposta`, `Resumo`,
`Tipo (Incidente/Solicitação)`, `Categoria`, `Data de Encerramento Virtual TI`.

A Decision **não tem** coluna `Responsável Resolução`, e nenhuma consulta dos
projetos tem. Ela não foi criada na Virtual TI: sem uma definição de referência,
uma coluna com esse nome seria uma regra nova.

## 9. Totais e arredondamento

Os índices são pontos percentuais por chamado. O total de FAIA de um período é
a soma de `Indice FAIA` do resultado, nas duas Contagens; o de FARC, a soma de
`Indice FARC`. A aplicação desse percentual sobre valores de contrato não faz
parte da consulta (seção 11).

**Arredondamento.** O Anexo VII (1.3.1, 1.3.2) fala do "somatório de horas ou
fração de horas (até duas casas decimais)". A consulta não arredonda em duas
casas: o excesso é calculado em segundos e convertido em horas com 6 casas, e o
arredondamento fica para quem soma. Medido nos 293 chamados resolvidos de
01/2025 a 10/2026, agrupados por mês, tipo e prioridade, as interpretações
quase não diferem:

| Interpretação | FAIA total | FARC total |
|---|---|---|
| sem arredondar | 15,559667 | 1354,468500 |
| excesso de cada chamado em 2 casas | 15,560000 | 1354,468000 |
| somatório do grupo em 2 casas | 15,560000 | 1354,468000 |
| índice do grupo em 2 casas | 15,560000 | 1354,450000 |

A maior diferença num grupo é 0,002 ponto percentual.

## 10. Cuidados e limitações

- **Os feriados do ano novo precisam ser cadastrados** no arquivo de feriados
  (as datas únicas: feriados móveis e pontos facultativos; os fixos `MM-DD` já
  valem todo ano). A mudança é só no arquivo; o SQL não muda.
- Identidade do grupo por UUID: `Fornecedores - Virtual`
  (`0x21679DF702A0EC478B1468D89E769836`). O nome do grupo é lido do cadastro,
  porque o `act_log` registra a transferência pelo nome.
- Chamados em `Em homologação pelo fiscal` não têm `close_date` nem
  `resolve_date` e não entram em nenhum dos dois modos.
- No modo `RESOLUCAO`, a busca de chamados que passaram pela Virtual TI lê o
  `act_log` de todos os chamados resolvidos no período; numa janela de 12 meses
  a consulta leva cerca de 50 segundos, contra 1 a 2 segundos no modo
  `FECHAMENTO`.
- Escopo, marcos e cálculo vêm do SDM, e os parâmetros estão no próprio SQL. O
  único dado externo é a lista de feriados, recebida em `@Feriados`.

## 11. Fora do escopo

- **Abatimento financeiro por item contratual.** O Anexo VII soma FAIA e FARC
  por item do Edital (itens 2, 3 e 4; Tabela 3, Equações 3, 6 e 10 a 13) e
  aplica o percentual ao valor mensal de cada item. A consulta entrega o índice
  de cada chamado e **não** calcula valor mensal, abatimento nem FAIA/FARC
  financeiro por item; também não classifica o chamado por item. Isso não muda
  a população nem o cálculo de FAIA e FARC por chamado.
- **Suspensão aprovada pelo TCU.** A consulta não lê aceite de suspensão nem
  arquivo externo de suspensões. As pausas são as da mecânica operacional
  (status não ativos e tempo fora da posse, seção 7.2).

## 12. Diferenças conhecidas em relação ao texto do contrato

Registradas para quem comparar a consulta com o Anexo VII. São escolhas
operacionais do usuário, não pendências:

| Ponto | Texto do Anexo VII | Consulta |
|---|---|---|
| Primeiro atendimento (T1) | assinatura do analista no campo "responsável"; resposta inicial = T1 − T0 (3.1.6, 3.1.7) | 1º `Em andamento` na posse; `Tini` = tempo de posse até ele (congelado) |
| Início da contagem | registro do chamado (T0, 3.1.6) | primeira entrada na Virtual TI; tempo em outro grupo não conta |
| Tempo de resolução | T0 a T2, sem homologação e suspensão justificada (3.1.8) | posse da Virtual TI em status ativo até a Resolução (7.2) |
| Reclassificação | 3.2.4, 3.5 | prioridade gravada no chamado (7.4) |
| Reabertura | prazos desde a abertura original; prioridade +1 (3.7.5, 3.8.3) | linha do tempo operacional (7.3); prioridade gravada |

## 13. Rastreabilidade

Fonte oficial dos documentos citados: pacote do Edital PE 90028/2025 no
Comprasnet (<https://comprasnet.gov.br/ConsultaLicitacoes/download/download_editais_detalhe.asp?coduasg=30001&modprp=5&numprp=900282025>).

| Regra | Fonte | Item/cláusula | Implementação SQL |
|---|---|---|---|
| Tipos de chamado: incidente e solicitação | Anexo VII | Tabela 1 | bloco `[3]`: `type IN ('I','R')` |
| Prioridades 1 a 5 | Anexo VII | 3.2, Tabela 4 | `call_req.priority`; coluna `Prioridade` |
| Metas de resposta inicial e resolução | Anexo VII | Tabela 1 | bloco `[1]`, `MetaRespostaH`, `MetaResolucaoH` |
| Cobertura (Contagem) 24x7 / Horário TCU | Anexo VII | Tabela 1 | bloco `[1]`, `Contagem` |
| Fatores FAIA e FARC | Anexo VII | Tabela 2 | bloco `[1]`, `FatorFAIA`, `FatorFARC` |
| Horário TCU: 8h–20h, seg–sex, dias úteis | Anexo VII | 3.1.13 | blocos `[2]` (feriados) e `[8]` (`#Virt_DiaUtil`) |
| 24x7: 00:00:00–23:59:59, ininterrupto | Anexo VII | 3.1.14 | bloco `[11]`: excesso sobre o tempo corrido |
| Feriados e pontos facultativos | Portarias do TCU | — | `docs/feriados.txt` → `@Feriados`, bloco `[2]` |
| Excesso por chamado | Anexo VII | 1.3.1, 1.3.2, Equações 1 e 4 | bloco `[11]`, `exc_resp_s`, `exc_sol_s` |
| Índice = excesso × fator | Anexo VII | Equações 2 e 5 | bloco `[11]`, `indice_faia`, `indice_farc` |
| Colunas do relatório analítico | Anexo VII | 6.19 | mapa da seção 8 |
| Tempo de parada de contagem | Anexo VII | 6.19.13 | `Tempo Parada Contagem NMS (h)` |
| Extração automatizada do SDM | Anexo VII | 3.1.10, 6.23 | consulta única, sem etapa manual |
| Posse, Primeiro Atendimento, Tempo Primeiro Atendimento, Tempo de Atendimento | mecânica operacional preservada (Decision adaptada; não é regra do Anexo VII) | — | blocos `[5]`–`[6.1]`, `[6]` (início), `[9]`, `[10]` |
