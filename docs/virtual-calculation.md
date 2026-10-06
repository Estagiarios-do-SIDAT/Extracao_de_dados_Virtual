# Apuração FAIA e FARC — Virtual

Regras da consulta [`queries/consulta_virtual_faia_farc.sql`](../queries/consulta_virtual_faia_farc.sql),
que apura FAIA e FARC do fornecedor **Virtual** direto do SDM (`mdb`).

A população vem só do SDM. A responsabilidade temporal segue a arquitetura de
posse da Decision (`Extracao_de_dados_Decision`): conta só o tempo em que o
chamado esteve no grupo `Fornecedores - Virtual`. Metas, fatores, regime,
calendário e horário comercial são os da Virtual e ficam dentro da própria
consulta. Não há dependência de arquivo externo.

---

## Índice

1. [Saída](#1-saída)
2. [Escopo e período](#2-escopo-e-período)
3. [TCU x 24x7](#3-tcu-x-24x7)
4. [Marcos temporais](#4-marcos-temporais)
5. [Calendário](#5-calendário)
6. [Parâmetros](#6-parâmetros)
7. [Cálculo por chamado](#7-cálculo-por-chamado)
8. [Mapa das colunas](#8-mapa-das-colunas)
9. [Totais](#9-totais)
10. [Cuidados e limitações](#10-cuidados-e-limitações)

---

## 1. Saída

Uma execução devolve **dois resultados**, com as mesmas 40 colunas:

| Resultado | Conteúdo |
|---|---|
| 1 | `Chamados_TCU` — todos os chamados elegíveis do regime TCU |
| 2 | `Chamados_24x7` — todos os chamados elegíveis do regime 24x7 |

Parâmetros, no topo do arquivo:

| Parâmetro | Significado |
|---|---|
| `@DataInicio` | início do período, inclusivo, horário do Brasil |
| `@DataFim` | fim do período, **exclusivo** |
| `@DataReferencia` | `N'FECHAMENTO'` (padrão) ou `N'RESOLUCAO'`: data do período e marco em que a responsabilidade da Virtual é validada (seção 2) |

Para um mês inteiro, use o dia 1 do mês e o dia 1 do mês seguinte (por exemplo
`2026-05-01` e `2026-06-01`). Nunca `23:59:59`.

Uma linha por chamado. As colunas vêm em três blocos (lista completa na seção 8):

| Bloco | Colunas |
|---|---|
| A — identificação e datas | 1 a 9: do `ID Chamado` até `Data/Hora Fechamento` |
| B — apuração da Virtual | 10 a 24: `Tini (h)` até `Indice FAIA` |
| C — contexto no padrão da Decision | 25 a 37: `Status` até `Meta Atendimento` |
| D — grupo atual, agendamento e encerramento | 38: `Grupo`; 39: `Indicador de Agendamento`; 40: `Data de Encerramento Virtual` |

Os chamados vêm todos juntos, separados só pelo regime. Para distinguir o
serviço ou o objeto atendido, use os dados do próprio chamado:
`Item de Configuração`, `Categoria`, `Descrição do Chamado`, `Status` e os
responsáveis.

## 2. Escopo e período

O período e a validação de responsabilidade dependem de `@DataReferencia`,
escolhida em uma linha no topo do arquivo:

| Modo | Data do período | Campo obrigatório | Responsabilidade validada em |
|---|---|---|---|
| `N'FECHAMENTO'` (padrão) | `Data/Hora Fechamento` (`call_req.close_date`) | `close_date` | fechamento: o chamado encerrou na Virtual |
| `N'RESOLUCAO'` | `Data/Hora Resolução` (`call_req.resolve_date`) | `resolve_date` (`close_date` pode estar vazio) | instante da resolução: dentro de uma janela de posse da Virtual |

Nos dois modos o chamado precisa ser **Incidente** ou **Solicitação** (`type`
`I` ou `R`); os parâmetros da Virtual não têm Problema nem Mudança. Não há
substituição entre as datas: se a data do modo estiver vazia, o chamado não
entra. Qualquer outro valor de `@DataReferencia` interrompe a consulta com o erro
*Valor inválido para @DataReferencia. Use RESOLUCAO ou FECHAMENTO.*

**FECHAMENTO.** O chamado entra quando:

1. `close_date` está preenchido e cai em `[@DataInicio, @DataFim)`;
2. está em **status terminal**: `CL`, `CLD`, `CLUNRSLV`, `CNCL`, `ATGR`, `END`,
   `PC`, `RE` ou `VARES` (a mesma lista da Decision, lida por código);
3. o **grupo atual** é `Fornecedores - Virtual`;
4. **encerrou na Virtual**: nasceu na Virtual e nunca teve transferência de
   grupo, ou a **última transferência de grupo até o fechamento** foi uma
   entrada na Virtual.

O item 4 é verificado pela cadeia de transferências do `act_log` (`TR`,
`Transferir Grupo de 'X' para 'Y'`), em ordem de `system_time` e `act_log.id`,
e não só pelo grupo atual. Um chamado `COI → Virtual → COI → fechamento` não é
encerramento da Virtual e fica fora.

**RESOLUCAO.** O chamado entra quando:

1. `resolve_date` está preenchido e cai em `[@DataInicio, @DataFim)`;
2. passou pela Virtual (grupo atual Virtual ou alguma transferência de grupo
   para ela);
3. **a resolução ocorreu dentro de uma janela de posse da Virtual**:
   `resolve_date` maior ou igual ao início de uma janela e menor ou igual ao
   fim dela; janela ainda aberta vale para qualquer instante posterior ao
   início.

Não se exige fechamento, status terminal nem grupo atual: entra o chamado
resolvido no período e ainda em `Em homologação`, e entra o chamado resolvido
na Virtual e depois devolvido ao COI. Um chamado resolvido pelo COI depois de
sair da Virtual fica fora.

A chave só muda **quais chamados entram**. Marcos, janelas de posse, tempos,
metas, excessos, índices, regime e as colunas de data continuam iguais para o
mesmo chamado nos dois modos. Para chamado ainda não fechado,
`Data/Hora Fechamento` sai vazia e os tempos terminam na resolução, nunca na
data atual.

Exemplos:

| SDM | Resolução | Fechamento | `FECHAMENTO` | `RESOLUCAO` |
|---|---|---|---|---|
| 1697694 | 04/05/2026 | 08/05/2026 | maio | maio |
| 1704841 | 28/05/2026 | 03/06/2026 | junho | maio |
| 1696948 | 29/04/2026 | 05/05/2026 | maio | abril |
| 1736039 | 30/09/2026 | — (em homologação) | não entra | setembro |
| 1651174 | 20/07/2026 (na Virtual) | 24/07/2026 (no COI) | não entra | julho |
| 1644738 | 29/09/2025 (pelo COI, após sair da Virtual) | 29/09/2025 | não entra | não entra |

**Nasceu na Virtual** quando o grupo de origem da primeira transferência de
grupo é a Virtual; sem nenhuma transferência de grupo, vale o grupo atual. É o
caso, por exemplo, de rotinas registradas pela automação direto na fila.

## 3. TCU x 24x7

O regime vem dos parâmetros da Virtual (seção 6), pela combinação
**Tipo + Prioridade**:

| | P1 | P2 | P3 | P4 | P5 |
|---|---|---|---|---|---|
| Incidente | 24x7 | 24x7 | TCU | TCU | — |
| Solicitação | 24x7 | 24x7 | TCU | TCU | TCU |

O regime não é informado em nenhum campo do SDM. Regime `24x7` vai para o
resultado `Chamados_24x7`; os demais vão para `Chamados_TCU`. A prioridade é a
do chamado no momento da consulta (`call_req.priority`, 1 a 5).

## 4. Marcos temporais

Todos em horário do Brasil (UTC−3), a partir dos campos em epoch do SDM.

| Coluna | Origem |
|---|---|
| `Data/Hora Abertura` | `call_req.open_date` |
| `Data Entrada Grupo Virtual` | primeira entrada na Virtual: a primeira transferência de grupo para `Fornecedores - Virtual`; se nasceu na Virtual, a abertura |
| `Data/Hora Início Atendimento` | primeira passagem para **`Em andamento`** (evento `ST`/`RE`) feita **enquanto o chamado está no grupo Virtual**: a captura da Decision. Sem ela, a primeira atividade registrada na posse; sem atividade, a entrada na Virtual |
| `Data/Hora Resolução` | `call_req.resolve_date`, gravado quando o chamado vai para `Em homologação` (evento `RE`) |
| `Data/Hora Fechamento` | `call_req.close_date`, gravado no encerramento do chamado (evento `CL`, em geral pela automação, dias depois da resolução) |
| `Data de Encerramento Virtual` | último **encerramento** da Virtual durante a posse: entrada em `Em homologação` ou `SOLN` (ver abaixo); vazia se não houver |

**Início do atendimento.** Ao transferir para a Virtual, o COI devolve o
chamado para `Aguarda atendimento`. O início é a primeira vez que a Virtual põe
o chamado em `Em andamento`, como a captura da Decision. Passar antes para
`Agendado` não é início: o chamado ainda não foi atendido. Um `Em andamento` só
conta se houver uma entrada na Virtual antes dele e nenhuma saída entre essa
entrada e o evento, inclusive no mesmo segundo; um `Em andamento` dado pelo COI
fora da posse não conta.

Sem `Em andamento` dentro da posse, vale o fallback da Decision:

1. a **primeira atividade** registrada no `act_log` dentro da posse, de
   qualquer tipo exceto transferência (`TR`), com o mesmo critério de posse;
2. sem atividade, a **entrada na Virtual** (Tini = 0).

A atividade no mesmo segundo da entrada não conta: é a mudança de status que o
COI grava ao transferir o chamado.

**Resolução.** Quando `resolve_date` está vazio porque o chamado seguiu para um
status posterior sem marca de resolvido, vale o último evento `RE`, salvo se o
chamado estiver em atendimento aberto. Nos chamados do escopo, `resolve_date`
coincide com a última entrada em `Em homologação` dentro da posse da Virtual,
com no máximo 1 segundo de diferença de gravação.

**Grupo.** A coluna `Grupo` mostra o grupo associado ao chamado no SDM no
momento da consulta (`call_req.group_id`, pelo nome em `ca_contact`): para
chamado fechado, o grupo final; para chamado ainda aberto, o grupo atual. É
informativa e diferente das janelas históricas de posse: não define escopo,
período, responsabilidade nem tempos. Um chamado resolvido na Virtual e depois
devolvido ao COI aparece no modo `RESOLUCAO` com `Grupo = COI` (ex.: 1651174).

**Data de Encerramento Virtual.** É o equivalente da Data de Encerramento
Decision: o momento em que a Virtual encerrou sua atuação no chamado.

- Encerra a atuação:
  - um evento de status do `act_log` (`ST`, `RE`, `RO`, `CL`...) com
    **destino** `Em homologação` (código `EMHOM`);
  - um `SOLN` (solução registrada), que a Decision trata como entrada
    implícita em homologação.
- Vale só a **entrada**: o evento anterior na linha do tempo não pode ser
  outro encerramento. `Em homologação` → `Reaberto` não é encerramento, e
  `Em homologação pelo fiscal` é outro status. Um `SOLN` registrado com o
  chamado já em homologação não é novo encerramento (ex.: 1681392, `SOLN` às
  14:47:36 depois da homologação das 11:31:07).
- O evento precisa estar dentro da posse da Virtual, com o mesmo critério do
  Início. Entradas em homologação antes da primeira entrada na Virtual ou
  depois de uma saída não contam; com várias passagens, valem todas as janelas.
- Com reabertura e nova homologação, vale a **última** entrada válida. Exemplo:
  1650824 foi para `Em homologação` em 07/11/2025 15:50:25, voltou a
  `Aguarda atendimento` às 17:12:52 e foi de novo para homologação às 17:13:55;
  a Data de Encerramento Virtual é 17:13:55.
- Um `SOLN` anterior a uma reabertura não é o encerramento final: vale o
  encerramento do último ciclo. Exemplo: 1660920 teve `SOLN` em 01/12/2025
  18:03:15, foi reaberto (`RO`) em 02/12 19:17:32, voltou a `Em andamento` e foi
  para homologação em 16/12 11:08:09; a Data de Encerramento Virtual é
  16/12 11:08:09.
- Chamado encerrado só por `SOLN`, sem `Em homologação`, fica com a data do
  `SOLN` (ex.: 1644896, `SOLN` às 14:22:51 e `resolve_date` às 14:25:41).
- Sem evento válido, fica **vazia**. Não há substituto por `resolve_date`,
  `close_date`, `LOG` ou última atividade.

**Encerramento Virtual x Resolução.** Na maior parte dos chamados as duas
datas coincidem, porque o SDM grava `resolve_date` na ida para homologação;
às vezes `resolve_date` sai 1 segundo antes do evento. Nos encerrados por
`SOLN`, o `resolve_date` sai alguns segundos depois do `SOLN`, junto com o envio
da pesquisa. São conceitos
diferentes: a `Data/Hora Resolução` é o marco dos tempos (Tsol, Tempo suspenso)
e do modo `RESOLUCAO`; a Data de Encerramento Virtual é informativa e não muda
população, tempos nem índices.

**Resolução x Fechamento.** São marcos diferentes: a resolução é a entrega da
Virtual; o fechamento é o encerramento do chamado no SDM. Qual dos dois define
o período é escolhido em `@DataReferencia` (seção 2).

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

## 5. Calendário

O calendário TCU fica no bloco `[2]` do motor (`#Virt_Calendario`), com quatro
campos: `Data`, `Tipo` (Feriado / Facultativo), `Descrição` e `Conta_SLA`.

- `Conta_SLA = 'N'`: a data **não tem horário comercial**.
- Qualquer outro valor: a data conta como dia normal. Na tabela, só 05/03/2025
  (quarta-feira de cinzas) não é `N`.
- Não existe contagem parcial de dia: um dia útil vale das 08:00 às 20:00 inteiro.

São 43 datas, de 01/01/2025 a 31/12/2026. A lista não foi conferida com fonte
oficial externa.

## 6. Parâmetros

Ficam no bloco `[1]` do motor (`#Virt_Parametros`). Metas em horas:

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

## 7. Cálculo por chamado

### 7.1 Janelas de posse da Virtual

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
  Tini 0:24:20 (6:34 da janela 1 + 17:46 da janela 2, até o Início)
  Tsol 24:33:32 (só em Em andamento; os 24:20 em Aguarda atendimento são Tempo suspenso)
```

### 7.2 Status ativos e Tempo suspenso

Dentro da posse, o Tempo de Atendimento (`Tsol`) conta só os status
**ativos**, os mesmos da Decision:

| Status | Código | Tsol |
|---|---|---|
| `Em andamento` | `FIP` | conta |
| `Aberto, aguarda atendimento` | `OP` | conta |
| `Aguarda atendimento`, `Agendado`, `Aguarda fornecedor`, `Em homologação`, `Reaberto`, `Resolvido, concluído` e os demais | — | pausa; vai para `Tempo suspenso` |

A linha do tempo de status vem de todo registro do `act_log` com o texto
`Status alterado de 'X' para 'Y'.`, qualquer que seja o tipo: `ST` (mudança
manual), `RE` (ida para `Em homologação`), `RO` (reabertura), `CL`
(encerramento). Os eventos seguem a ordem de `system_time` e, no empate, de
`act_log.id`. Na abertura vale a origem `X` do primeiro evento (sem evento,
`Aberto, aguarda atendimento`); a partir de cada evento vale o destino `Y`, até o
evento seguinte.

Um `SOLN` (solução registrada) muda o status sem gravar a transição. Como na
Decision, ele entra na linha do tempo como passagem para um status não ativo,
que vale até o evento seguinte. Exemplo (SDM 1660920): solução em 01/12 18:03:15,
reabertura (`RO`, `Resolvido, concluído` → `Reaberto`) em 02/12 19:17:32 e volta
a `Em andamento` às 19:17:38. As 25:14:23 entre a solução e a volta ao
atendimento são `Tempo suspenso`, e não `Tsol`.

`Tsol` é a interseção, até a Resolução, das janelas de posse com os trechos
ativos, somada em todas as janelas. `Tempo suspenso` é o restante da posse
até a Resolução:

```text
Tsol + Tempo suspenso = tempo de posse até a Resolução
```

Exemplo (SDM 1698592, duas passagens):

```text
05/05 15:25:33 entrada na Virtual (Aguarda atendimento)   pausa       0:01:27
05/05 15:27:00 Em andamento -> Início                     Tsol        0:05:10
05/05 15:32:10 saída para o COI                           fora da posse
06/05 16:09:58 reentrada (Aguarda atendimento)            pausa       0:01:42
06/05 16:11:40 Em andamento                               Tsol        2:04:14
06/05 18:15:54 Em homologação -> Resolução
Tini 0:01:27   Tsol 2:09:24   Tempo suspenso 0:03:09
```

Um chamado em `Agendado` por meses dentro da posse (rotinas que a Virtual
reagenda) acumula esse tempo em `Tempo suspenso`, e não em `Tsol`.

### 7.3 Colunas

As colunas de duração (as 10 do bloco B e `Tempo suspenso`) saem como **texto
`[h]:mm:ss`**: horas sem limite de 24 (`73:21:56`, `360:00:00`), minutos e
segundos com dois dígitos, zero como `0:00:00`. O cálculo é todo feito em
**segundos inteiros**; o texto é montado só no fim, depois de calculados
excessos e índices. Fatores e índices saem como números e nunca são calculados
a partir do texto.

| Coluna | TCU | 24x7 |
|---|---|---|
| `Tini (h)` | tempo corrido nas janelas de posse até o Início, em qualquer status | igual |
| `Tsol (h)` | tempo corrido nas janelas de posse até a Resolução, só em status ativo (7.2) | igual |
| `Horas Comerciais Resposta (h)` | parte de Tini dentro de 08:00–20:00, seg–sex, fora das datas `N` | 0 |
| `Horas Não Comerciais Resposta (h)` | Tini − Comerciais Resposta | Tini |
| `Horas Comerciais Resolução (h)` | parte de Tsol (trechos ativos) dentro da janela comercial | 0 |
| `Horas Não Comerciais Resolução (h)` | Tsol − Comerciais Resolução | Tsol |
| `Meta Resposta (h)` / `Meta Resolução (h)` | parâmetro | parâmetro |
| `Excesso Resposta (h)` | máx(0, Comerciais Resposta − Meta Resposta) | máx(0, Tini − Meta Resposta) |
| `Excesso Resolução (h)` | máx(0, Comerciais Resolução − Meta Resolução) | máx(0, Tsol − Meta Resolução) |
| `Indice FAIA` | Excesso Resposta × Fator FAIA | igual |
| `Indice FARC` | Excesso Resolução × Fator FARC | igual |
| `Tempo suspenso` | posse até a Resolução − Tsol, corrido | igual |
| `Meta Primeiro Atendimento` | `Não Atende` se Excesso Resposta > 0; `Atende` se 0; `N/A` sem valor | igual |
| `Meta Atendimento` | o mesmo, sobre Excesso Resolução | igual |

- A janela comercial é calculada dia a dia. Em cada dia útil conta a
  sobreposição do trecho com 08:00–20:00. Sábado e domingo não contam,
  independentemente de `SET DATEFIRST`.
- As horas comerciais e não comerciais são medidas sobre os mesmos trechos do
  tempo de que fazem parte. Valem sempre: Tini = Comerciais Resposta + Não
  Comerciais Resposta; Tsol = Comerciais Resolução + Não Comerciais Resolução.
- `Tempo suspenso` é informativo: já está fora de `Tsol` e não é descontado de
  novo de nenhum excesso ou índice.
- **Índice** é expresso em **pontos percentuais**: horas de excesso × fator,
  com o excesso em segundos convertido para horas (6 casas). Exemplo: 8,065 h
  de excesso × 0,4 = 3,226.
- Com o fallback da captura (seção 4), todo chamado que entrou na Virtual tem
  Início.

Correspondência com as colunas da Decision:

| Virtual | Decision |
|---|---|
| `Tini (h)` | Tempo Primeiro Atendimento |
| `Tsol (h)` | Tempo de Atendimento |
| `Excesso Resposta (h)` | Primeiro Atendimento Excedido |
| `Excesso Resolução (h)` | Tempo Atendimento Excedido |

A arquitetura é a da Decision; a Virtual mantém o próprio regime, calendário,
horário 08–20, metas e fatores. A Decision tem dois motores com listas de
status ativos diferentes: o do `Tempo Total Decision` e do `Tempo suspenso`
(ativos: `Aberto, aguarda atendimento`, `Aguarda atendimento`, `Em andamento`,
`Reaberto`) e o do `Tempo de Atendimento`, que gera o FARC (ativos: só
`Em andamento` e `Aberto, aguarda atendimento`). O `Tsol` segue o segundo,
porque é ele que define o excesso e o índice.

Diferenças em relação à Decision:

| Regra | Decision | Virtual | Motivo |
|---|---|---|---|
| Captura | 1º `Em andamento` após a entrada, em qualquer grupo | 1º `Em andamento` dentro da posse | o `Em andamento` dado pelo COI depois de o chamado sair da Virtual não é atendimento da Virtual |
| Tempo Primeiro Atendimento | intervalo contínuo da entrada à captura | só o tempo de posse até a captura | tempo em outro grupo não é responsabilidade da Virtual |
| Passagens no Tempo de Atendimento | a partir da última entrada | todas as janelas de posse | a Virtual atende em mais de uma passagem; as janelas são as do motor de posse da Decision |
| Fim do Tempo de Atendimento | 1º `SOLN`, senão `resolve_date` | Resolução (`resolve_date`), com o `SOLN` como pausa | na Virtual a entrega é a ida para `Em homologação` (`resolve_date`); o `SOLN` é raro e pode ser seguido de reabertura |
| Estado no início | heurística pela origem do 1º `ST` | origem do 1º evento e, depois, o destino de cada evento | regra do motor de posse da Decision; a heurística trata `Aguarda fornecedor` como ativo |
| `Tempo suspenso` | posse da abertura ao `close_date`, em status fora dos 4 ativos do `Tempo Total Decision` (inclui a espera em homologação até o fechamento), mais `SOLN` → pesquisa; corrido | posse até a Resolução − `Tsol`; corrido | a Virtual não tem `Tempo Total Decision`; `Tempo suspenso` é o complemento do `Tsol` no mesmo intervalo, e a homologação depois da Resolução é do cliente |
| Data de Encerramento | última entrada em `Em homologação` na posse, por `ST`/`CL` ou `SOLN` implícito; `RE` só como fallback quando não há nenhuma | última entrada em `Em homologação` na posse, por qualquer evento de status, ou `SOLN` implícito | na Virtual o `RE` é o registro usual da homologação e já é lido como evento de status; com ele como fallback, um `SOLN` anterior a uma reabertura venceria a homologação final (1660920) |

### 7.4 Indicadores

| Coluna | Pergunta | Fonte | Depende da posse? | Valores |
|---|---|---|---|---|
| `Tempo suspenso` | quanto tempo da posse, até a Resolução, ficou em status que pausam? | linha do tempo de status (7.2) ∩ janelas de posse (7.1) | sim: tempo fora da Virtual nunca entra | `[h]:mm:ss` |
| `Indicador Reabertura` | o chamado foi reaberto? | `act_log` com tipo contendo `reab` ou descrição/ação contendo `reabert`, em todo o histórico do chamado (regra [6] da Decision) | não | `Sim` / `Não` |
| `Indicador de Agendamento` | o chamado passou para `Agendado` enquanto estava com a Virtual? | registro de status do `act_log` com **destino** `Agendado` (código `AGENDADO`), dentro de uma janela de posse | sim | `Sim` / `Não` |

- **Reabertura não é tempo ativo.** `Indicador Reabertura = Sim` só diz que
  houve reabertura. O status `Reaberto` pausa o `Tsol` como qualquer status não
  ativo; o atendimento volta a contar quando o chamado volta a `Em andamento`
  ou `Aberto, aguarda atendimento`. Exemplo: 1660920, reaberto por `RO` em
  02/12/2025 19:17:32 (`Resolvido, concluído` → `Reaberto`).
- **Agendamento pelo destino.** Só conta a transição *para* `Agendado`
  (`Em andamento` → `Agendado`). `Agendado` → `Em andamento` não prova entrada em
  `Agendado`. O evento precisa estar dentro da posse com o mesmo critério do
  Início: entrada antes do evento e nenhuma saída entre a entrada e o evento,
  inclusive no mesmo segundo. Um `Agendado` gravado pelo COI no segundo da
  transferência para a Virtual, ou antes dela, não conta; o chamado que chega
  à Virtual já `Agendado` só tem `Sim` se a Virtual o agendar de novo. O tempo
  em `Agendado` na posse vai para `Tempo suspenso` em qualquer caso.
- Os indicadores não mudam tempos, excessos nem índices.

## 8. Mapa das colunas

| # | Campo final | Origem | Regra |
|---|---|---|---|
| 1 | ID Chamado | `call_req.ref_num` | — |
| 2 | Descrição do Chamado | `call_req.summary` | resumo atual |
| 3 | Tipo (Incidente/Solicitação) | `call_req.type` | I → Incidente, R → Solicitação |
| 4 | Prioridade | `call_req.priority` | 1 a 5 |
| 5 | Regime | parâmetros | por Tipo + Prioridade; define o resultado |
| 6 | Data/Hora Abertura | `open_date` | seção 4 |
| 7 | Data/Hora Início Atendimento | `act_log`: 1º `Em andamento` dentro da posse; senão 1ª atividade na posse; senão a entrada | seção 4 |
| 8 | Data/Hora Resolução | `resolve_date` / último RE | seção 4; define o período com `RESOLUCAO` |
| 9 | Data/Hora Fechamento | `close_date` | seção 4; define o período com `FECHAMENTO` |
| 10 | Tini (h) | janelas de posse até 7 | corrido, `[h]:mm:ss`; Tempo Primeiro Atendimento |
| 11 | Tsol (h) | janelas de posse até 8, só status ativo | corrido, `[h]:mm:ss`; Tempo de Atendimento |
| 12 | Horas Comerciais Resposta (h) | parte comercial de 10 | calendário; 24x7 = 0 |
| 13 | Horas Não Comerciais Resposta (h) | 10 − 12 | 24x7 = Tini |
| 14 | Horas Comerciais Resolução (h) | parte comercial de 11 | calendário; 24x7 = 0 |
| 15 | Horas Não Comerciais Resolução (h) | 11 − 14 | 24x7 = Tsol |
| 16 | Meta Resposta (h) | parâmetros | Tipo + Prioridade |
| 17 | Meta Resolução (h) | parâmetros | Tipo + Prioridade |
| 18 | Excesso Resposta (h) | 12 (TCU) ou 10 (24x7) − 16 | mín. 0 |
| 19 | Excesso Resolução (h) | 14 (TCU) ou 11 (24x7) − 17 | mín. 0 |
| 20 | chave | 3, 4, 5 | `Tipo\|Prioridade\|Regime` |
| 21 | Fator FARC | parâmetros | pela chave |
| 22 | Indice FARC | 19 × 21 | pontos percentuais |
| 23 | Fator FAIA | parâmetros | pela chave |
| 24 | Indice FAIA | 18 × 23 | pontos percentuais |
| 25 | Status | `cr_stat.sym` do status atual | `N/A` sem cadastro |
| 26 | Categoria | `prob_ctg.sym` (área/tipo da solicitação) | `N/A` sem categoria |
| 27 | Responsável Abertura | `call_req.log_agent` → `ca_contact` | nome; senão userid; senão `N/A` |
| 28 | Responsável Atendimento | `call_req.assignee` → `ca_contact` | idem |
| 29 | Item de Configuração | `call_req.affected_rc` → `ca_owned_resource` | vazio sem IC |
| 30 | Data Entrada Grupo Virtual | primeira entrada na Virtual | seção 4 |
| 31 | Tempo suspenso | janelas de posse até 8 − 11 | corrido, `[h]:mm:ss`; posse em status que pausam (seção 7.2) |
| 32 | Meta Primeiro Atendimento | 18 | `Atende` / `Não Atende` / `N/A` |
| 33 | Indicador Reabertura | `act_log`: tipo com `reab` ou texto com `reabert`, todo o histórico | `Sim` / `Não`; não depende da posse (seção 7.4) |
| 34 | Acordo Prazo | — | `-` (campo reservado, como na Decision) |
| 35 | Acordo Qualidade | — | `-` |
| 36 | Justificativa | — | `-` |
| 37 | Meta Atendimento | 19 | `Atende` / `Não Atende` / `N/A` |
| 38 | Grupo | `call_req.group_id` → `ca_contact.last_name` | grupo atual do chamado no SDM; vazio sem grupo (seção 4) |
| 39 | Indicador de Agendamento | `act_log`: transição com destino `Agendado` dentro da posse | `Sim` / `Não` (seção 7.4) |
| 40 | Data de Encerramento Virtual | `act_log`: último encerramento dentro da posse (entrada em `Em homologação` ou `SOLN`) | data e hora; vazia sem evento válido (seção 4) |

## 9. Totais

Os índices são pontos percentuais por chamado. O total de FAIA de um período é
a soma de `Indice FAIA` dos dois resultados; o de FARC, a soma de
`Indice FARC`. A aplicação desse percentual sobre valores de contrato não faz
parte da consulta.

## 10. Cuidados e limitações

- **O calendário precisa ser atualizado a cada ano.** Ele cobre 01/01/2025 a
  31/12/2026. As datas ficam no bloco `[2]` do motor, tabela `#Virt_Calendario`,
  em `queries/consulta_virtual_faia_farc.sql`. Inclua as datas do ano novo
  nesse bloco e copie o bloco para os dois arquivos de `powerbi/` (ver
  `docs/powerbi-query.md`, seção 2). Sem isso, os feriados do ano novo não são
  descontados.
- Identidade do grupo por UUID: `Fornecedores - Virtual`
  (`0x21679DF702A0EC478B1468D89E769836`). O nome do grupo é lido do cadastro,
  porque o `act_log` registra a transferência pelo nome.
- Chamados em `Em homologação pelo fiscal` não têm `close_date` nem
  `resolve_date` e não entram em nenhum dos dois modos.
- No modo `RESOLUCAO`, a busca de chamados que passaram pela Virtual lê o
  `act_log` de todos os chamados resolvidos no período; numa janela de 12 meses
  a consulta leva cerca de 50 segundos, contra 1 a 2 segundos no modo
  `FECHAMENTO`.
- A consulta não lê arquivos externos: escopo, marcos e cálculo vêm do SDM, e
  parâmetros e calendário estão no próprio SQL.
