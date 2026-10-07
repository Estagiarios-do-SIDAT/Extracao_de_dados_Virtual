# Apuração FAIA e FARC — Virtual

Regras da consulta [`queries/consulta_virtual_faia_farc.sql`](../queries/consulta_virtual_faia_farc.sql),
que apura FAIA e FARC do fornecedor **Virtual** direto do SDM (`mdb`).

**Fonte funcional: Edital PE 90028/2025 e anexos da contratação**, em especial
o **Anexo VII — Níveis Mínimos de Serviço** (código de autenticidade 77219622),
com apoio dos Anexos I, VIII e IX. Metas, cobertura, fatores, marcos, horário
de contagem, suspensão, reclassificação e reabertura vêm desses documentos
(seção 13). Parte da técnica de leitura do SDM (linha do tempo do `act_log`,
janelas de posse) foi reaproveitada da Decision; ela não é fonte de regra.
A população vem só do SDM. Os feriados vêm do arquivo de feriados (seção 5 e
[feriados.md](feriados.md)).

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
11. [Item contratual (n ∈ N): bloqueio funcional](#11-item-contratual-n--n-bloqueio-funcional)
12. [Pontos do contrato não demonstráveis pelo SDM](#12-pontos-do-contrato-não-demonstráveis-pelo-sdm)
13. [Rastreabilidade contratual](#13-rastreabilidade-contratual)

---

## 1. Saída

Uma execução devolve **um resultado**, com 42 colunas: todos os chamados
elegíveis, nas duas Contagens. A coluna `Contagem` diz a janela de contagem de
cada chamado (seção 3). Até 2026-10-06 eram dois resultados, `Chamados_TCU` e
`Chamados_24x7`, com as mesmas colunas.

Parâmetros, no topo do arquivo:

| Parâmetro | Significado |
|---|---|
| `@DataInicio` | início do período, inclusivo, horário do Brasil |
| `@DataFim` | fim do período, **exclusivo** |
| `@DataReferencia` | `N'FECHAMENTO'` (padrão) ou `N'RESOLUCAO'`: data do período e marco em que a responsabilidade da Virtual é validada (seção 2) |

Para um mês inteiro, use o dia 1 do mês e o dia 1 do mês seguinte (por exemplo
`2026-05-01` e `2026-06-01`). Nunca `23:59:59`.

Uma linha por chamado. As colunas vêm em blocos (lista completa na seção 8):

| Bloco | Colunas |
|---|---|
| A — identificação e datas | 1 a 9: do `ID Chamado` até `Data/Hora Fechamento` |
| B — apuração | 10 a 24: `Tini (h)` até `Indice FAIA` |
| C — contexto e apoio à fiscalização | 25 a 39: `Status` até `Situação Meta Resolução` |
| D — grupo, agendamento e encerramento | 40: `Grupo`; 41: `Indicador de Agendamento`; 42: `Data de Encerramento Virtual` |

## 2. Escopo e período

O período e a validação de responsabilidade dependem de `@DataReferencia`,
escolhida em uma linha no topo do arquivo:

| Modo | Data do período | Campo obrigatório | Responsabilidade validada em |
|---|---|---|---|
| `N'FECHAMENTO'` (padrão) | `Data/Hora Fechamento` (`call_req.close_date`) | `close_date` | fechamento: o chamado encerrou na Virtual |
| `N'RESOLUCAO'` | `Data/Hora Resolução` (`call_req.resolve_date`) | `resolve_date` (`close_date` pode estar vazio) | instante da resolução: dentro de uma janela de posse da Virtual |

Nos dois modos o chamado precisa ser **Incidente** ou **Solicitação** (`type`
`I` ou `R`): o Anexo VII só define níveis de serviço para esses dois tipos
(Tabela 1; 3.1.1). Não há substituição entre as datas: se a data do modo
estiver vazia, o chamado não entra. Qualquer outro valor de `@DataReferencia`
interrompe a consulta com o erro *Valor inválido para @DataReferencia. Use
RESOLUCAO ou FECHAMENTO.*

**FECHAMENTO.** O chamado entra quando:

1. `close_date` está preenchido e cai em `[@DataInicio, @DataFim)`;
2. está em **status terminal**: `CL`, `CLD`, `CLUNRSLV`, `CNCL`, `ATGR`, `END`,
   `PC`, `RE` ou `VARES` (lidos por código);
3. o **grupo no fechamento** é `Fornecedores - Virtual`: nasceu na Virtual e
   nunca teve transferência de grupo, ou a **última transferência de grupo até
   o fechamento** foi uma entrada na Virtual.

O item 3 é verificado pela cadeia de transferências do `act_log` (`TR`,
`Transferir Grupo de 'X' para 'Y'`), em ordem de `system_time` e `act_log.id`;
o grupo atual do cadastro não decide. Ter passado pela Virtual não basta: um
chamado `COI → Virtual → COI → fechamento` fechou no COI e fica fora (ex.:
1651174, fechado em 24/07/2026 no COI). Uma transferência gravada no mesmo
segundo do fechamento conta antes dele, salvo se o registro `CL` desse segundo
tiver `act_log.id` menor.

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

A chave só muda **quais chamados entram**. Marcos, tempos, metas, excessos,
índices, Contagem e as colunas de data continuam iguais para o mesmo chamado
nos dois modos. Para chamado ainda não fechado, `Data/Hora Fechamento` sai
vazia e os tempos terminam na resolução, nunca na data atual.

**População x contrato.** O Anexo VII pede o levantamento do ciclo de
faturamento (2.2) e, nos relatórios consolidados, o "quantitativo de chamados
abertos no período" (6.15.1, 6.16.1). O contrato não diz qual data põe um
chamado no ciclo para o cálculo do excesso; o FARC só existe depois do T2. Por
isso a escolha entre fechamento e resolução continua sendo de
`@DataReferencia` (decisão do usuário de 2026-10-05), e nenhum filtro de
população mudou na revisão contratual de 2026-10-07. Cancelados (`CNCL`,
`ATGR`) entram no modo `FECHAMENTO` se tiverem resolução; o cancelamento só é
permitido com autorização do TCU (3.7.2), que o SDM não registra.

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
grupo é a Virtual; sem nenhuma transferência de grupo, vale o grupo atual.

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

- **Uma Contagem por chamado**, a mesma para a resposta inicial e para a
  resolução, como na Tabela 1 (uma cobertura por linha).
- A Contagem não está em nenhum campo do SDM. A prioridade é a do chamado no
  momento da consulta (`call_req.priority`, 1 a 5); ver reclassificação na
  seção 7.5.
- Até 2026-10-07 a coluna se chamava `Tipo SLA`, com os valores `Corrida`
  (24x7) e `Comercial` (Horário TCU), e a `chave` usava `TCU`. Só os nomes
  mudaram: o mesmo chamado tem a mesma janela.

## 4. Marcos temporais

Todos em horário do Brasil (UTC−3), a partir dos campos em epoch do SDM.

| Marco do contrato (3.1.6) | Coluna | Origem no SDM |
|---|---|---|
| T0 — Registro | `Data/Hora Abertura` | `call_req.open_date` |
| T1 — Resposta inicial | `Data/Hora Início Atendimento` | **regra operacional congelada** (abaixo) |
| T2 — Resolução | `Data/Hora Resolução` | `call_req.resolve_date`; se vazio, o último evento `RE` |
| — | `Data Entrada Grupo Virtual` | primeira transferência de grupo para `Fornecedores - Virtual`; se nasceu na Virtual, a abertura |
| — | `Data/Hora Fechamento` | `call_req.close_date` (evento `CL`, em geral pela automação, dias depois da resolução) |
| — | `Data de Encerramento Virtual` | último encerramento da Virtual durante a posse (abaixo); informativa |

**T0.** O registro do chamado no SDM (3.1.6 i). É o `open_date`, exato nas
planilhas NMS mensais do TCU (`Data/Hora Abertura`).

**T1 — congelado.** O Anexo VII define T1 como "o horário que o chamado foi
assinado por um analista da contratada no campo 'responsável'" (3.1.6 ii) e a
resposta inicial do FAIA como T1 − T0 (3.1.7). A Virtual mantém, por decisão do
usuário, a regra operacional anterior, sem nenhuma alteração nesta revisão:

- início = primeira passagem para **`Em andamento`** (evento `ST`/`RE`) feita
  **enquanto o chamado está no grupo Virtual**; sem ela, a primeira atividade
  registrada no `act_log` dentro da posse (exceto `TR`); sem atividade, a
  entrada na Virtual;
- `Tini (h)` (Tempo Primeiro Atendimento) = tempo de posse da Virtual até o
  início (seção 7.1), e não T1 − T0.

Divergências conhecidas com o contrato: o evento (status `Em andamento` x
assinatura do responsável) e a origem (entrada na Virtual x registro). Em 289
dos 293 chamados resolvidos entre 01/2025 e 10/2026 o chamado foi registrado
fora do grupo Virtual e entrou nele depois (mediana 7,5 min; 15 com mais de
1 h). Essas diferenças não foram corrigidas: `Data/Hora Início Atendimento` e
`Tini (h)` são entradas imutáveis do FAIA.

**T2.** A resolução pela contratada (3.1.6 iii). No SDM, `resolve_date` é
gravado na ida para `Em homologação` (evento `RE`): coincide com a última
entrada em `Em homologação` em 286 dos 293 chamados (±1 s), e com o registro da
solução (`SOLN`) nos outros 7. Quando `resolve_date` está vazio porque o
chamado seguiu para um status posterior sem marca de resolvido, vale o último
evento `RE`, salvo se o chamado estiver em atendimento aberto.

**Grupo.** A coluna `Grupo` é o grupo do chamado no instante de referência,
pela linha do tempo de transferências de grupo:

- `FECHAMENTO`: o grupo no fechamento, o mesmo que decide o escopo; como o
  escopo exige a Virtual, todas as linhas trazem `Fornecedores - Virtual`;
- `RESOLUCAO`: o grupo no instante da resolução (última transferência de
  grupo antes de `resolve_date`).

**Data de Encerramento Virtual.** Coluna informativa, sem equivalente no
contrato: o momento em que a Virtual encerrou sua atuação no chamado.

- Encerra a atuação um evento de status do `act_log` (`ST`, `RE`, `RO`, `CL`...)
  com **destino** `Em homologação` (código `EMHOM`), ou um `SOLN` (solução
  registrada).
- Vale só a **entrada**: o evento anterior na linha do tempo não pode ser
  outro encerramento.
- O evento precisa estar dentro da posse da Virtual, com o mesmo critério do
  início. Com reabertura e nova homologação, vale a **última** entrada válida
  (ex.: 1650824 → 07/11/2025 17:13:55; 1660920 → 16/12/2025 11:08:09).
- Sem evento válido, fica **vazia**.
- Não muda população, tempos nem índices. O marco do FARC é a
  `Data/Hora Resolução` (T2).

Exemplo (SDM 1697694):

```text
01/05 09:00:05  INIT  automação                       -> T0 (Abertura)
01/05 09:13:39  ST    Aberto, aguarda atendimento -> Em andamento   (COI)
01/05 09:21:55  ST    Em andamento -> Aguarda atendimento           (COI)
01/05 09:21:55  TR    Grupo 'COI' -> 'Fornecedores - Virtual'       -> Entrada na Virtual
01/05 09:35:23  ST    Aguarda atendimento -> Em andamento           -> Início (congelado)
01/05 09:35:24  TR    Responsável '' -> Willian Correa dos Santos   (não muda a posse)
04/05 10:22:01  RE    Em andamento -> Em homologação                -> T2 (Resolução)
08/05 10:45:39  CL    Em homologação -> Resolvido, concluído        -> Fechamento
```

## 5. Calendário

Os feriados e pontos facultativos vêm do **arquivo de feriados**: o calendário
do TCU, o mesmo da Decision e da A2B ([feriados.md](feriados.md)). O bloco `[2]` do motor
recebe a lista no parâmetro `@Feriados`, valida cada data e monta
`#Virt_Feriado` (datas únicas, `AAAA-MM-DD`) e `#Virt_FeriadoAnual` (fixos,
`MM-DD`, todo ano). Quem preenche `@Feriados`: `tools/executar_consulta.ps1`
(consulta de referência) e `powerbi/consulta_virtual_chamados_power_bi.m`
(Power BI, a partir do SharePoint). Sem `@Feriados`, ou com lista vazia ou
inválida, a consulta para com erro: nunca calcula com zero feriados.

- Uma data do arquivo **não é dia útil**: fica fora do Horário TCU (3.1.13).
  Não existe contagem parcial de dia: um dia útil vale das 08:00 às 20:00
  inteiro.
- Sábado e domingo nunca estão no Horário TCU.
- Hoje o arquivo tem 35 linhas: os 9 feriados nacionais fixos (todo ano) e
  13 datas de 2025 e 13 de 2026, das Portarias do TCU.

Até 2026-10-06 a lista ficava no próprio SQL (`#Virt_Calendario`, 43 datas de
2025 e 2026, com `Conta_SLA`). Desde 2026-10-07 a Virtual usa o calendário
único do TCU.

## 6. Parâmetros

Ficam no bloco `[1]` do motor (`#Virt_Parametros`), transcritos do Anexo VII:
metas e cobertura da **Tabela 1**, fatores da **Tabela 2** (% por hora ou
fração de hora excedida). Conferidos no PDF original em 2026-10-07; são os
mesmos usados desde a primeira versão (vindos das planilhas NMS), sem
divergência.

| Tipo | Prioridade | Meta Resposta (resposta inicial) | Meta Resolução | Contagem (Cobertura) | Fator FAIA | Fator FARC | chave |
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

### 7.1 Janelas de posse da Virtual

As **janelas de posse** são os trechos em que o chamado esteve no grupo
`Fornecedores - Virtual`, pela linha do tempo de grupo (a abertura, no grupo
inicial, e cada transferência de grupo do `act_log`, em ordem de `system_time`
e `act_log.id`). Saída fecha a janela; reentrada abre outra.

Desde 2026-10-07 a posse **não desconta tempo do FARC**. Ela é usada:

- pelo início e pelo `Tini` (congelados, seção 4);
- pela coluna informativa `Tempo Fora Grupo Virtual (h)`;
- pelo escopo (seção 2), pela `Data de Encerramento Virtual` e pelo
  `Indicador de Agendamento`.

### 7.2 Tsol: de T0 a T2, sem homologação

O Anexo VII 3.1.8 define o tempo de resolução do FARC como o tempo "entre o
registro do chamado (T0 – Registro) no service desk até a conclusão dos
procedimentos para atendimento do chamado (T2 – Resolução)", e diz: "Não são
contabilizados os intervalos de tempo utilizados para homologação dos
resultados obtidos ou os intervalos de tempo em que o chamado esteve suspenso
de forma justificada."

A consulta aplica:

```text
Tsol = (T2 − T0) − homologação entre T0 e T2
```

A homologação vem da linha do tempo de status do chamado. Cada trecho de
status entre T0 e T2 cai numa classe:

| Classe | Status (código) | No `Tsol` | Fundamento |
|---|---|---|---|
| Homologação | `Em homologação` (`EMHOM`), `Em homologação pelo fiscal` (`CQ`) | **não conta**; vai para `Tempo Parada Contagem NMS` | 3.1.8, 3.7.1 |
| Agendado | `Agendado` (`AGENDADO`) | **conta**; também sai em `Tempo Agendado` | 3.4.4, 3.6.1.2 (seção 7.3) |
| Demais | `Em andamento`, `Aberto, aguarda atendimento`, `Aguarda atendimento`, `Reaberto`, `Aguarda fornecedor`, `Suspenso`, `Resolvido, concluído` e qualquer outro | **conta** | 3.1.8 (só homologação e suspensão justificada saem); 3.4.1 |

- **Evidência da homologação no SDM.** O T2 é a entrada em `Em homologação`, e
  a homologação depois do T2 já está fora do intervalo. Antes do T2 só há
  homologação quando a solução foi recusada e o chamado voltou ao atendimento:
  1650824 (`Em homologação` 1:22:27 antes de voltar a `Aguarda atendimento`) e
  1647705 (`Em homologação pelo fiscal` 0:03:32). `Em teste/homologação`
  (`TESHOM`) e `Homologada pelo cliente` (`HOM`) nunca apareceram nos chamados
  da Virtual e não foram classificados como homologação só pelo nome.
- **Sem pausa por status.** O contrato não autoriza nenhum status a suspender o
  NMS automaticamente. `cr_stat.hold` não é usado.
- **SOLN.** O registro de solução não grava destino e não muda a linha do
  tempo: o status anterior continua valendo até o evento seguinte.
- **Tempo fora do grupo Virtual conta.** T0 é o registro do chamado, e não a
  entrada na Virtual (3.1.6). O tempo em outro grupo entre T0 e T2 sai na
  coluna informativa `Tempo Fora Grupo Virtual` (seção 7.3).
- A linha do tempo de status vem dos registros de status do próprio chamado no
  `act_log`: `ST`, `RE` (ida para `Em homologação`), `RO` (reabertura), `CL` e
  `CLREQ`, com o texto `Status alterado de 'X' para 'Y'.`, lido de
  `description` e, quando ela traz só o comentário do analista, de
  `action_desc`. Na abertura vale a origem `X` do primeiro evento (sem evento,
  `Aberto, aguarda atendimento`); a partir de cada evento vale o destino `Y`.

Exemplo (SDM 1650824, Solicitação P4, Horário TCU):

```text
17/10/2025 13:59:43  T0                                          conta
17/10 14:41:39       Em andamento -> Agendado                    conta (Tempo Agendado 505:06:16)
07/11 15:50:25       -> Em homologação                           NÃO conta (1:22:27)
07/11 17:12:52       -> Aguarda atendimento (solução recusada)   conta
07/11 17:13:55       -> Em homologação = T2
Tsol 505:51:45 = 507:14:12 − 1:22:27; Horário TCU 169:51:45 < meta 180 h; FARC 0
```

**Validação contra as planilhas NMS do TCU.** O `Tsol` corrigido é igual ao
`Tsol` (Resolução − Abertura) das planilhas mensais em 10 de 11 chamados de
maio/2026, 20 de 21 de julho/2026 e 24 de 26 do ciclo de 2025 (antes: 0 em
todas). As diferenças: 1704841 (4 s); 1716548 (a planilha traz a resolução
igual ao início); 1647705 e 1650824 (a planilha não desconta a homologação do
3.1.8).

### 7.3 Suspensão justificada: o que o SDM não prova

O contrato admite interromper a contagem só **a critério do TCU** (3.6.1):
razões aceitas pelo TCU, agendamento acordado com o TCU ou ação necessária do
TCU. Agendamento ou qualquer mudança de estado que suspenda o NMS exige
anuência prévia do TCU ou procedimento documentado em conjunto, com a
justificativa registrada (3.4.3, 3.4.4).

No SDM:

- os 33 chamados com `Agendado` entre T0 e T2 (resolvidos de 01/2025 a
  10/2026) foram agendados por usuários terceirizados (`X` + CPF), um deles
  membro do próprio grupo Virtual;
  a justificativa, quando existe, é texto livre no `LOG` (por exemplo
  "aguardando inclusão do usuário no sistema CONTRATA"), e não há campo de
  aceite do TCU;
- o tempo em outro grupo não tem registro de motivo nem de aceite.

Por isso a consulta **não desconta** suspensão. Para a fiscalização avaliar,
saem duas colunas informativas, já contidas no `Tsol`:

| Coluna | Conteúdo |
|---|---|
| `Tempo Agendado (h)` | tempo em `Agendado` entre T0 e T2 |
| `Tempo Fora Grupo Virtual (h)` | tempo entre T0 e T2 fora das janelas de posse da Virtual |

Tratamento auditável proposto (não implementado): manter as suspensões
reconhecidas pelo TCU num arquivo externo, como o de feriados (chamado,
início, fim, motivo, documento de aceite), lido pela consulta como parâmetro e
descontado do `Tsol` como parada justificada. Assim o desconto fica rastreável
até o aceite, sem inferir autorização a partir de status.

### 7.4 Reabertura

O fechamento sem autorização é reaberto e "os prazos serão contados novamente a
partir da abertura original do chamado" (3.7.5); a reabertura pelos fiscais
segue a mesma regra e aumenta a prioridade em 1, salvo exceção alinhada com os
fiscais (3.8.3).

- **Prazo.** O `Tsol` vai de T0 (abertura original) ao **último** T2, contando o
  tempo em `Reaberto` e o tempo entre a solução e a reabertura; só a
  homologação sai. Exemplo: 1660920 teve `SOLN` em 01/12/2025 18:03:15 (o
  chamado passou a `Resolvido, concluído`), foi reaberto (`RO`) em 02/12
  19:17:32 e resolvido em 16/12 11:08:09; as 25:14:17 entre a solução e a
  reabertura contam (antes eram `Tempo suspenso`).
- **Prioridade.** A consulta usa a prioridade gravada no chamado. No único caso
  com `RO` (1660920) a prioridade foi de 3 para 2 no segundo da reabertura e
  voltou a 3 um minuto depois; a consulta não força o +1, porque o SDM registra
  a decisão final (que pode ser a exceção prevista no 3.8.3).
- **FAIA.** O início e o `Tini` continuam os da primeira passagem (congelados).
- `Indicador Reabertura` diz se houve reabertura (`act_log` com tipo contendo
  `reab` ou texto com `reabert`); nas populações publicadas só 1660920 tem `Sim`.

### 7.5 Reclassificação de prioridade

O SDM registra a troca de prioridade no `act_log` (`ESC`, `Alterado
'Prioridade' de 'X' para 'Y'`). Nas populações de 2025–2026:

| Caso | Chamados | Regra do contrato | Consulta |
|---|---|---|---|
| Classificação inicial (`NãoInformada` → P2/P3), minutos após o registro | 9 | 3.1.9, 3.2.4 | prioridade gravada, desde T0 |
| Menos rigorosa: 1719182 (Inc 1 → 2, após 4,39 h), 1727892 (Sol 4 → 5, após 337 h) | 2 | 3.5.2.3: a contagem obedece à nova prioridade | prioridade gravada (a nova), desde T0 |
| Mais rigorosa e volta: 1660920 (3 → 2 → 3 em 1 min, na reabertura) | 1 | 3.8.3 | prioridade final |
| Mais rigorosa com novo chamado (3.5.2.1/3.5.2.2) | 0 | novo chamado; o original fica suspenso até o novo terminar | sem caso; o vínculo entre os chamados não é lido |

Ponto em aberto (seção 12): o 3.2.4 diz que, na (re)classificação de um
incidente, os prazos "passam a contar a partir do momento da classificação ou
reclassificação... como se aberto fosse" naquele momento. A consulta não
reinicia T0 na reclassificação: o 3.5.2.3 só diz que vale a nova prioridade, e a
planilha NMS de julho/2026 cobrou 1719182 desde a abertura (FARC 28,218, igual
ao da consulta). Reiniciar daria 26,46 em 1719182 e mudaria pouco os demais.

### 7.6 Colunas

As colunas de duração saem como **texto `[h]:mm:ss`**: horas sem limite de 24
(`73:21:56`, `360:00:00`), minutos e segundos com dois dígitos, zero como
`0:00:00`. O cálculo é todo feito em **segundos inteiros**; o texto é montado
só no fim. Fatores e índices saem como números e nunca são calculados a partir
do texto.

| Coluna | Regra |
|---|---|
| `Tini (h)` | tempo de posse até o início, corrido (congelado) |
| `Tsol (h)` | T2 − T0 − homologação, corrido (7.2) |
| `Horas Horário TCU Resposta (h)` | parte do `Tini` dentro do Horário TCU (seção 5), nas duas Contagens |
| `Horas Fora Horário TCU Resposta (h)` | `Tini` − Horário TCU Resposta |
| `Horas Horário TCU Resolução (h)` | parte do `Tsol` dentro do Horário TCU, nas duas Contagens |
| `Horas Fora Horário TCU Resolução (h)` | `Tsol` − Horário TCU Resolução |
| `Meta Resposta (h)` / `Meta Resolução (h)` | Tabela 1 |
| `Excesso Resposta (h)` | Horário TCU: máx(0, Horário TCU Resposta − Meta Resposta); 24x7: máx(0, `Tini` − Meta Resposta) |
| `Excesso Resolução (h)` | Horário TCU: máx(0, Horário TCU Resolução − Meta Resolução); 24x7: máx(0, `Tsol` − Meta Resolução) |
| `Indice FAIA` | Excesso Resposta (horas, 6 casas) × Fator FAIA |
| `Indice FARC` | Excesso Resolução (horas, 6 casas) × Fator FARC |
| `Tempo Parada Contagem NMS (h)` | homologação entre T0 e T2 (descontada do `Tsol`; 6.19.13) |
| `Tempo Agendado (h)` | `Agendado` entre T0 e T2 (informativo; está no `Tsol`) |
| `Tempo Fora Grupo Virtual (h)` | T0 a T2 fora das janelas de posse (informativo; está no `Tsol`) |
| `Meta Primeiro Atendimento` | `Não Atende` se Excesso Resposta > 0; `Atende` se 0; `N/A` sem valor |
| `Situação Meta Resolução` | o mesmo, sobre Excesso Resolução |

- O Horário TCU é calculado dia a dia: em cada dia útil conta a sobreposição do
  trecho com 08:00–20:00. Sábado, domingo e datas do arquivo de feriados não
  contam, independentemente de `SET DATEFIRST`.
- Valem sempre: `Tini` = Horário TCU Resposta + Fora Horário TCU Resposta;
  `Tsol` = Horário TCU Resolução + Fora Horário TCU Resolução;
  `Tsol` + `Tempo Parada Contagem NMS` = Resolução − Abertura.
- Na Contagem `24x7` as horas dentro e fora do Horário TCU são só informativas
  (até 2026-10-07 saíam 0 e o total); o excesso usa o tempo corrido.
- **Índice** em **pontos percentuais**: 8,065 h de excesso × 0,4 = 3,226.

### 7.7 Indicadores

| Coluna | Pergunta | Fonte | Valores |
|---|---|---|---|
| `Indicador Reabertura` | o chamado foi reaberto? | `act_log` com tipo contendo `reab` ou descrição/ação contendo `reabert`, em todo o histórico | `Sim` / `Não` |
| `Indicador de Agendamento` | o chamado passou para `Agendado` enquanto estava com a Virtual? | registro de status com **destino** `Agendado`, dentro de uma janela de posse | `Sim` / `Não` |

Os indicadores não mudam tempos, excessos nem índices. O `Indicador de
Agendamento` olha só a posse da Virtual; o `Tempo Agendado` olha todo o
intervalo T0–T2.

## 8. Mapa das colunas

| # | Campo final | Origem | Regra | Termo do contrato |
|---|---|---|---|---|
| 1 | ID Chamado | `call_req.ref_num` | — | número do chamado (2.2, 6.19.6) |
| 2 | Resumo | `call_req.summary` | sem espaços nas pontas | breve descrição do chamado (6.19.14) |
| 3 | Tipo (Incidente/Solicitação) | `call_req.type` | I → Incidente, R → Solicitação | tipo (6.19.2) |
| 4 | Prioridade | `call_req.priority` | número 1 a 5 | prioridade (Tabela 4) |
| 5 | Contagem | parâmetros | `24x7` / `Horário TCU` / `N/A` | cobertura (Tabela 1) |
| 6 | Data/Hora Abertura | `open_date` | seção 4 | T0 – Registro |
| 7 | Data/Hora Início Atendimento | `act_log` | congelado (seção 4) | T1 – Resposta inicial (regra divergente) |
| 8 | Data/Hora Resolução | `resolve_date` / último RE | seção 4 | T2 – Resolução |
| 9 | Data/Hora Fechamento | `close_date` | seção 4 | encerramento (3.7) |
| 10 | Tini (h) | posse até 7 | congelado | resposta inicial (3.1.7; regra divergente) |
| 11 | Tsol (h) | 8 − 6 − homologação | 7.2 | tempo de resolução (3.1.8) |
| 12 | Horas Horário TCU Resposta (h) | parte de 10 no Horário TCU | 7.6 | Horário TCU (3.1.13) |
| 13 | Horas Fora Horário TCU Resposta (h) | 10 − 12 | 7.6 | — |
| 14 | Horas Horário TCU Resolução (h) | parte de 11 no Horário TCU | 7.6 | Horário TCU (3.1.13) |
| 15 | Horas Fora Horário TCU Resolução (h) | 11 − 14 | 7.6 | — |
| 16 | Meta Resposta (h) | parâmetros | Tabela 1 | resposta inicial |
| 17 | Meta Resolução (h) | parâmetros | Tabela 1 | resolução |
| 18 | Excesso Resposta (h) | 12 (Horário TCU) ou 10 (24x7) − 16 | mín. 0 | Exc (Equação 1); tempo extrapolado |
| 19 | Excesso Resolução (h) | 14 (Horário TCU) ou 11 (24x7) − 17 | mín. 0 | Exc (Equação 4); tempo extrapolado (6.19.13) |
| 20 | chave | 3, 4, 5 | `Tipo\|Prioridade\|Contagem` | — |
| 21 | Fator FARC | parâmetros | Tabela 2 | fator FARC |
| 22 | Indice FARC | 19 × 21 | pontos percentuais | IndFARC (Equação 5) |
| 23 | Fator FAIA | parâmetros | Tabela 2 | fator FAIA |
| 24 | Indice FAIA | 18 × 23 | pontos percentuais | IndFAIA (Equação 2) |
| 25 | Status | `cr_stat.sym` do status atual | `N/A` sem cadastro | status do chamado (6.19.1) |
| 26 | Categoria | `prob_ctg.sym` | `N/A` sem categoria | categorização (3.1.4) |
| 27 | Responsável Abertura | `call_req.log_agent` → `ca_contact` | nome; senão userid; senão `N/A` | quem abriu (2.2) |
| 28 | Responsável Atendimento | `call_req.assignee` → `ca_contact` | idem | responsável pelo atendimento (6.19.8) |
| 29 | Item de Configuração | `call_req.affected_rc` → `ca_owned_resource` | vazio sem IC | — |
| 30 | Data Entrada Grupo Virtual | primeira entrada na Virtual | seção 4 | — (3.4.1) |
| 31 | Tempo Parada Contagem NMS (h) | homologação entre 6 e 8 | 7.2 | tempo total de parada de contagem de NMS (6.19.13) |
| 32 | Tempo Agendado (h) | `Agendado` entre 6 e 8 | informativo (7.3) | agendamento (3.4.4, 3.6.1.2) |
| 33 | Tempo Fora Grupo Virtual (h) | 6 a 8 fora da posse | informativo (7.3) | — |
| 34 | Meta Primeiro Atendimento | 18 | `Atende` / `Não Atende` / `N/A` | — |
| 35 | Indicador Reabertura | `act_log` | `Sim` / `Não` (7.7) | reabertura (3.8) |
| 36 | Acordo Prazo | — | `-` (campo reservado) | — |
| 37 | Acordo Qualidade | — | `-` | — |
| 38 | Justificativa | — | `-` | justificativa (6.15.2, 6.16.2) |
| 39 | Situação Meta Resolução | 19 | `Atende` / `Não Atende` / `N/A` | — |
| 40 | Grupo | `act_log` (transferências) | grupo no fechamento ou na resolução | — |
| 41 | Indicador de Agendamento | `act_log` | `Sim` / `Não` (7.7) | — |
| 42 | Data de Encerramento Virtual | `act_log` | informativa (seção 4) | — |

### 8.1 Nomes revisados em 2026-10-07

| Antes | Depois | Fundamento |
|---|---|---|
| `Tipo SLA` (`Corrida` / `Comercial`) | `Contagem` (`24x7` / `Horário TCU`) | decisão do usuário; Anexo VII Tabela 1 (cobertura), 3.1.13, 3.1.14 |
| `Severidade` (`3 - Média`) | `Prioridade` (`3`) | o contrato usa "prioridade" (3.2, Tabela 4); a Tabela 4 só rotula 1 a 4 (CRÍTICA, ALTA, MÉDIA, BAIXA) e não rotula a 5, por isso sai o número |
| `Horas Comerciais` / `Horas Não Comerciais` | `Horas Horário TCU` / `Horas Fora Horário TCU` | o contrato não usa "horário comercial"; a janela é o Horário TCU (3.1.13) |
| `Tempo suspenso` | `Tempo Parada Contagem NMS (h)` | 6.19.13; o conteúdo mudou (só o que é descontado do `Tsol`) |
| `Meta Atendimento` | `Situação Meta Resolução` | a coluna avalia a meta de **resolução** (Tabela 1); "atendimento" no contrato vai de T1 a T2 e confundia com o primeiro atendimento |
| `chave` com `TCU` | `chave` com `Horário TCU` | acompanha a Contagem |

Mantidos: `Data/Hora Início Atendimento`, `Tini (h)` (congelados, por decisão
do usuário), `Meta Primeiro Atendimento` (mesmo grupo de nomes do primeiro
atendimento), `Tsol (h)` (nome da Equação 4), `Excesso` (Exc das Equações),
`Meta Resposta`, `Resumo`, `Tipo (Incidente/Solicitação)`, `Categoria`,
`Data de Encerramento Virtual` (informativa, sem termo no contrato).

Não há `Responsável Resolução`: sem uma definição de referência, uma coluna com
esse nome seria uma regra nova.

## 9. Totais e arredondamento

Os índices são pontos percentuais por chamado. Pelo Anexo VII:

```text
Exc_sp       = Σ_i [Max(T_i | Meta_sp) − Meta_sp]        por tipo s e prioridade p   (Eq. 1 e 4)
IndFAIA_sp   = Exc_sp × FatorFAIA_sp                                                 (Eq. 2)
ValorFAIA_n  = Σ_s Σ_p IndFAIA_sp                         por item n ∈ N              (Eq. 3)
(FARC igual, Eq. 4 a 6)
IndItem_n    = ValorFAIA_n + ValorFARC_n + ...;  FAItem_n = Min(IndItem_n | 30%)      (Eq. 10 a 13)
```

A consulta entrega a parcela de cada chamado (`Indice FAIA`, `Indice FARC`). O
total de um período é a soma por item contratual (seção 11). A aplicação do
percentual sobre o valor mensal do item não faz parte da consulta.

**Arredondamento.** O 1.3.1 e o 1.3.2 falam do "somatório de horas ou fração de
horas (até duas casas decimais)". A consulta não arredonda em duas casas: o
excesso é calculado em segundos e convertido em horas com 6 casas, e o
arredondamento fica para o somatório. Medido nos 293 chamados resolvidos de
01/2025 a 10/2026, agrupados por mês, tipo e prioridade, as interpretações
quase não diferem:

| Interpretação | FAIA total | FARC total |
|---|---|---|
| sem arredondar | 15,559667 | 1948,750111 |
| excesso de cada chamado em 2 casas | 15,560000 | 1948,756000 |
| Exc_sp (somatório) em 2 casas | 15,560000 | 1948,750000 |
| índice do grupo em 2 casas | 15,560000 | 1948,740000 |

A maior diferença num grupo é 0,002 ponto percentual. A leitura mais próxima
do texto é arredondar o somatório (Exc_sp), na consolidação.

## 10. Cuidados e limitações

- **Os feriados do ano novo precisam ser cadastrados** no arquivo de feriados
  (as datas únicas; os fixos `MM-DD` já valem todo ano). A mudança é só no
  arquivo; o SQL não muda.
- Identidade do grupo por UUID: `Fornecedores - Virtual`
  (`0x21679DF702A0EC478B1468D89E769836`). O nome do grupo é lido do cadastro,
  porque o `act_log` registra a transferência pelo nome.
- Chamados em `Em homologação pelo fiscal` não têm `close_date` nem
  `resolve_date` e não entram em nenhum dos dois modos.
- No modo `RESOLUCAO`, a busca de chamados que passaram pela Virtual lê o
  `act_log` de todos os chamados resolvidos no período; numa janela de 12 meses
  a consulta leva cerca de 50 segundos, contra 1 a 2 segundos no modo
  `FECHAMENTO`.
- Escopo, marcos e cálculo vêm do SDM, e os parâmetros estão no próprio SQL. O
  único dado externo é a lista de feriados, recebida em `@Feriados`.

## 11. Item contratual (n ∈ N): bloqueio funcional

A Tabela 3 do Anexo VII define `N` = grupo de itens (itens **2, 3 e 4** do
Edital), e o FAIA e o FARC são somados **por item** (Equações 3 e 6) e
aplicados ao valor mensal de cada item (`VMItem_n`, Equação 13). Os itens:

| Item | Objeto (Relação de Itens do PE 90028/2025) | Grupos de atividades (Anexo IX, Tabela 3) |
|---|---|---|
| 2 | gestão especializada e monitoramento on-site e proativo de ambiente crítico | Grupo 1 (comuns) e Grupos 2 a 11 — "Itens 2 e 3" |
| 3 | serviços técnicos com dedicação exclusiva de mão de obra (postos de trabalho) | idem — "Itens 2 e 3" |
| 4 | suporte remoto do fabricante, atualização e gestão do software DCIM | Grupo 1 (comuns) e Grupo 12 (DCIM) |

**A consulta não separa os chamados por item**, e o total por item não pode ser
montado com segurança a partir dela. O que falta:

1. **Campo no SDM.** Nenhum campo do chamado registra o item contratual.
2. **Associação no contrato.** O Anexo IX liga os grupos de atividades aos
   "itens 2 e 3" **juntos**; não há regra que separe um chamado do item 2 de um
   do item 3. O Grupo 1 (atividades comuns) vale para os três itens.
3. **Categoria só resolve parte.** Das categorias de 2025–2026,
   `Virtual TI.DCIM` aponta para o item 4 e `Energia e UPS`, `Climatização`,
   `CFTV e Controle de Acesso`, `Cabeamento` e `Infraestrutura Predial do
   Datacenter` para os itens 2/3; mas `Realizar Checklist/HealthCheck` (162
   chamados), `Gestão de Acessos`, `Gestão de Solicitação`, `Gestão de
   Incidentes`, `Elaborar/Manter Documentação`, `Movimentação de Equipamentos`,
   `Gestão de Vulnerabilidades` e as categorias `COI.*` podem ser de qualquer
   item.
4. **Valores e itens do contrato da Virtual.** As planilhas NMS mensais usam
   duas partes, "DCIM" (R$ 16.000,00) e "Manutenção" (R$ 22.000,00), que não
   correspondem um a um aos três itens do Edital (valores estimados: item 2 R$
   45.904,37/mês, item 3 R$ 16.527,77/mês, item 4 R$ 18.484,21/mês). O contrato
   assinado, com os itens adjudicados à Virtual e seus valores mensais, não está
   entre os documentos usados.

Até 2026-10-02 a consulta tinha a separação "DCIM x Manutenção" das planilhas
(DCIM = aberto pela automação com IC `dcim`), removida por decisão do usuário:
era regra das planilhas, não do contrato. Para fechar o ponto é preciso uma
regra chamado → item aprovada pelo TCU (por exemplo por categoria, com a
destinação explícita das categorias comuns) e os itens e valores do contrato.

## 12. Pontos do contrato não demonstráveis pelo SDM

| Ponto | Contrato | Situação |
|---|---|---|
| T1 | assinatura do analista no campo "responsável" (3.1.6) | congelado na regra operacional (seção 4) |
| Suspensão justificada | a critério do TCU, com anuência (3.4.4, 3.6.1) | aceite não registrado; não descontada; colunas informativas (7.3) |
| Item contratual | soma por item (Tabela 3, Eq. 3/6) | bloqueio funcional (seção 11) |
| Reclassificação de incidente | prazos desde a (re)classificação (3.2.4) | não aplicado; contagem desde T0 com a prioridade gravada (7.5) |
| Reclassificação mais rigorosa | novo chamado; original suspenso (3.5.2.1/2) | sem caso; vínculo entre chamados não lido |
| Prioridade +1 na reabertura | 3.8.3, salvo exceção | prioridade gravada no SDM (7.4) |
| Arredondamento | somatório em 2 casas (1.3.1/1.3.2) | feito na consolidação (seção 9) |

## 13. Rastreabilidade contratual

| Regra | Documento | Item/cláusula | Implementação SQL |
|---|---|---|---|
| Tipos de chamado: incidente e solicitação | Anexo VII | 3.1.1, Tabela 1 | bloco `[3]`: `type IN ('I','R')` |
| Prioridades 1 a 5 | Anexo VII | 3.2, Tabela 4 | `call_req.priority`; coluna `Prioridade` |
| Metas de resposta inicial e resolução | Anexo VII | Tabela 1 | bloco `[1]`, `MetaRespostaH`, `MetaResolucaoH` |
| Cobertura (Contagem) 24x7 / Horário TCU | Anexo VII | Tabela 1 | bloco `[1]`, `Contagem` |
| Fatores FAIA e FARC | Anexo VII | Tabela 2 | bloco `[1]`, `FatorFAIA`, `FatorFARC` |
| Horário TCU: 8h–20h, seg–sex, dias úteis | Anexo VII | 3.1.13 | blocos `[2]` (feriados) e `[8]` (`#Virt_DiaUtil`) |
| 24x7: 00:00:00–23:59:59, ininterrupto | Anexo VII | 3.1.14 | bloco `[11]`: excesso sobre o tempo corrido |
| Feriados e pontos facultativos | Portarias do TCU | — | `config/feriados.csv` → `@Feriados`, bloco `[2]` |
| T0 – Registro | Anexo VII | 3.1.6 i | `open_date`; `Data/Hora Abertura` |
| T1 – Resposta inicial | Anexo VII | 3.1.6 ii, 3.1.7 | **congelado**: bloco `[6]` (início), `[10]` medida `R` |
| T2 – Resolução | Anexo VII | 3.1.6 iii, 3.1.8 | bloco `[6]`: `resolve_date` / último `RE` |
| Tsol = T2 − T0 sem homologação | Anexo VII | 3.1.8 | blocos `[9]` (classe `H`) e `[10]` (medida `S`) |
| Homologação | Anexo VII | 3.1.8, 3.7.1 | `EMHOM`, `CQ` → `Tempo Parada Contagem NMS` |
| Suspensão / interrupção | Anexo VII | 3.4.3, 3.4.4, 3.6.1 | não descontada; `Tempo Agendado`, `Tempo Fora Grupo Virtual` (bloco `[10]`) |
| Reabertura | Anexo VII | 3.7.5, 3.8.3 | `Tsol` de T0 ao último T2 (bloco `[10]`); `Indicador Reabertura` |
| Reclassificação | Anexo VII | 3.2.4, 3.5 | prioridade gravada (seção 7.5) |
| Excesso por chamado | Anexo VII | 1.3.1, 1.3.2, Equações 1 e 4 | bloco `[11]`, `exc_resp_s`, `exc_sol_s` |
| Índice = excesso × fator | Anexo VII | Equações 2 e 5 | bloco `[11]`, `indice_faia`, `indice_farc` |
| Soma por item | Anexo VII | Tabela 3, Equações 3 e 6 | fora da consulta; bloqueio (seção 11) |
| Itens 2, 3 e 4 | Edital PE 90028/2025, Relação de Itens; Anexo IX | Tabela 3 do Anexo IX | não implementado (seção 11) |
| Colunas do relatório analítico | Anexo VII | 6.19 | mapa da seção 8 |
| Tempo de parada de contagem | Anexo VII | 6.19.13 | `Tempo Parada Contagem NMS (h)` |
| Extração automatizada do SDM | Anexo VII | 3.1.10, 6.23 | consulta única, sem etapa manual |
