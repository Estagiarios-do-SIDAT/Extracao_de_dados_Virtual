# Consulta do Power BI — Virtual

Fonte de dados do painel de FAIA e FARC da Virtual. A regra de cálculo está em
[virtual-calculation.md](virtual-calculation.md): metas, fatores e Contagem do
Edital PE 90028/2025, Anexo VII (fonte oficial:
<https://comprasnet.gov.br/ConsultaLicitacoes/download/download_editais_detalhe.asp?coduasg=30001&modprp=5&numprp=900282025>);
Primeiro Atendimento, Tempo Primeiro Atendimento e Tempo de Atendimento pela
mecânica operacional preservada.

---

## 1. Arquivo

| Arquivo | Conteúdo |
|---|---|
| `powerbi/consulta_virtual_chamados_power_bi.m` | a consulta do relatório (Power Query M): lê o arquivo de feriados no SharePoint, valida e executa o SQL abaixo com o parâmetro `@Feriados`. Gerado por `tools/gerar_powerbi_m.ps1` |
| `powerbi/consulta_virtual_chamados_power_bi.sql` | o SQL: todos os chamados elegíveis da Virtual, nas duas Contagens; a coluna `Contagem` (`24x7` / `Horário TCU`) separa |

A consulta devolve **um único resultado**, como o Power BI espera. Ele substitui
as antigas `consulta_virtual_chamados_tcu_power_bi.sql` (`Chamados_TCU`) e
`consulta_virtual_chamados_24x7_power_bi.sql` (`Chamados_24x7`), removidas do
repositório: eram o mesmo motor com filtros opostos no regime (seção 7).

## 2. Mesmo motor da consulta de referência

A referência é [`queries/consulta_virtual_faia_farc.sql`](../queries/consulta_virtual_faia_farc.sql).
Os dois arquivos têm o mesmo bloco de cálculo, delimitado por:

```text
-- >>> MOTOR VIRTUAL
...
-- <<< MOTOR VIRTUAL
```

O bloco é **idêntico byte a byte** nos dois arquivos. SHA256 do bloco, com fim de
linha LF:

```text
1943c0bf0c13bb9d06607a469de4820ff29001ba4cc5887044d3fcad5735a2fe
```

Ele recebe `@DataInicio`, `@DataFim`, `@DataReferencia` e `@Feriados` (lista
de feriados, seção 3) e entrega a tabela `#Virt_Saida`, com as duas Contagens. Os arquivos diferem apenas no
período:

| | Referência | Power BI |
|---|---|---|
| Período | `@DataInicio` / `@DataFim` digitados | calculado a partir de hoje (seção 4) |
| Saída | um resultado, Horário TCU e 24x7 | igual |

As duas consultas têm as mesmas 40 colunas, na mesma ordem.

Qualquer mudança de regra é feita no bloco da referência e copiada para o
arquivo do Power BI. Depois da cópia, os dois blocos devem continuar idênticos.

## 3. Como usar no Power BI

O SQL não é mais colado em *Instrução SQL*: os feriados vêm de um arquivo no
SharePoint, que o SQL Server não lê. A consulta do relatório é o `.m`:

1. *Página Inicial → Nova Fonte → Consulta Nula → Editor Avançado*.
2. Colar `powerbi/consulta_virtual_chamados_power_bi.m` **inteiro**.
3. Trocar `INSERIR_URL_DO_ARQUIVO_FERIADOS_NO_SHAREPOINT` pelo link direto do
   `feriados.txt` no SharePoint (o mesmo da Decision e da A2B).
4. Credenciais: SQL Server como hoje; SharePoint com conta organizacional.
   Privacidade das duas fontes: **Organizacional**. No gateway, permitir fontes
   de nuvem.

A cada atualização o arquivo de feriados é lido de novo. Arquivo inacessível,
placeholder não preenchido ou linha inválida **falham a atualização** com
mensagem. O `.m` faz tudo num único passo (`Fonte`): a primeira versão gerada,
com um passo por etapa, era recusada pelo firewall de privacidade
(*Formula.Firewall*). A estrutura atual foi validada com o motor do Power BI
Desktop, com as duas fontes como Organizacional e sem ignorar níveis de
privacidade; o acesso ao SharePoint Online real e o refresh no serviço ainda
dependem de validação no PBIX. Detalhes, requisitos do serviço e o checklist do
primeiro refresh em [feriados.md](feriados.md).

É uma consulta só no modelo. Para separar as Contagens no relatório, filtre pela
coluna `Contagem`.

Mudança de regra: alterar `consulta_virtual_chamados_power_bi.sql`, gerar o
`.m` de novo (`.\tools\gerar_powerbi_m.ps1 -Consulta .\powerbi\consulta_virtual_chamados_power_bi.sql`)
e atualizar a consulta no PBIX. Mudança de feriado: só o arquivo no SharePoint.

## 4. Período

No topo do arquivo:

```sql
DECLARE @CoberturaMeses int = 12;
DECLARE @DataReferencia nvarchar(20) = N'FECHAMENTO';
```

`@DataReferencia` escolhe a data que define a janela, como na consulta de
referência:

| `@DataReferencia` | Data que define o período | Coluna usada |
|---|---|---|
| `N'FECHAMENTO'` (padrão) | fechamento | `Data/Hora Fechamento` (`call_req.close_date`) |
| `N'RESOLUCAO'` | resolução | `Data/Hora Resolução` (`call_req.resolve_date`) |

Com `FECHAMENTO`, entram chamados fechados no período e encerrados na Virtual.
Com `RESOLUCAO`, entram chamados resolvidos no período dentro de uma janela de
posse da Virtual, mesmo que ainda não tenham fechamento; nesse caso
`Data/Hora Fechamento` sai vazia. Trocar só essa linha muda quais chamados
entram; nenhum cálculo muda. Outro valor interrompe a atualização com erro.
Regra completa em
[virtual-calculation.md, seção 2](virtual-calculation.md#2-escopo-e-período).

A janela vai do **dia 1 do mês (corrente − `@CoberturaMeses`)** até o fim do dia
de hoje, pela data escolhida. Com `12`, ela traz os doze meses anteriores,
inteiros, e o mês corrente até hoje. Para outra cobertura, troque só esse
número (no Power BI, no início do texto `SqlTexto` do Editor Avançado; no
repositório, no `.sql`, gerando o `.m` de novo). Nenhuma regra depende dele.

Exemplo: atualizado em 15/10/2026, com `12` e `FECHAMENTO`, traz chamados
fechados de 01/10/2025 até 15/10/2026.

Volume de referência (janela de 01/10/2025 a 07/10/2026): 276 chamados com
`FECHAMENTO` (264 Horário TCU, 12 24x7), em cerca de 10 a 45 segundos; 293 com
`RESOLUCAO` (281 Horário TCU, 12 24x7), mais lento, porque o modo lê o
`act_log` de todos os chamados resolvidos na janela.

## 5. Saída

As mesmas 40 colunas da referência, na mesma ordem:

| # | Coluna | Unidade |
|---|---|---|
| 1 | ID Chamado | texto |
| 2 | Resumo | texto (`call_req.summary`) |
| 3 | Tipo (Incidente/Solicitação) | texto |
| 4 | Prioridade | número 1 a 5 (Tabela 4 do Anexo VII) |
| 5 | Contagem | `24x7` / `Horário TCU` / `N/A` (a "Cobertura" da Tabela 1) |
| 6 | Data/Hora Abertura | data e hora (Brasil) |
| 7 | Data/Hora Início Atendimento | data e hora (Brasil): início (congelado) |
| 8 | Data/Hora Resolução | data e hora (Brasil) |
| 9 | **Data/Hora Fechamento** | data e hora (Brasil) |
| 10 | Tini (h) | texto `[h]:mm:ss` (congelado) |
| 11 | Tsol (h) | texto `[h]:mm:ss`: Tempo de Atendimento (posse em status ativo) |
| 12 | Horas Horário TCU Resposta (h) | texto `[h]:mm:ss` |
| 13 | Horas Fora Horário TCU Resposta (h) | texto `[h]:mm:ss` |
| 14 | Horas Horário TCU Resolução (h) | texto `[h]:mm:ss` |
| 15 | Horas Fora Horário TCU Resolução (h) | texto `[h]:mm:ss` |
| 16 | Meta Resposta (h) | texto `[h]:mm:ss` |
| 17 | Meta Resolução (h) | texto `[h]:mm:ss` |
| 18 | Excesso Resposta (h) | texto `[h]:mm:ss` |
| 19 | Excesso Resolução (h) | texto `[h]:mm:ss` |
| 20 | chave | `Tipo\|Prioridade\|Contagem` (ex.: `Solicitação\|3\|Horário TCU`) |
| 21 | Fator FARC | decimal |
| 22 | Indice FARC | pontos percentuais |
| 23 | Fator FAIA | decimal |
| 24 | Indice FAIA | pontos percentuais |
| 25 | Status | texto |
| 26 | Categoria | texto |
| 27 | Responsável Abertura | texto |
| 28 | Responsável Atendimento | texto |
| 29 | Item de Configuração | texto |
| 30 | Data Entrada Grupo Virtual | data e hora (Brasil) |
| 31 | Tempo Parada Contagem NMS (h) | texto `[h]:mm:ss`: posse até a resolução em status que pausam |
| 32 | Meta Primeiro Atendimento | `Atende` / `Não Atende` / `N/A` |
| 33 | Indicador Reabertura | `Sim` / `Não`: o chamado foi reaberto |
| 34 | Acordo Prazo | `-` |
| 35 | Acordo Qualidade | `-` |
| 36 | Justificativa | `-` |
| 37 | Situação Meta Resolução | `Atende` / `Não Atende` / `N/A` |
| 38 | Grupo | texto: grupo no instante de referência (fechamento ou resolução) |
| 39 | Indicador de Agendamento | `Sim` / `Não`: passou para `Agendado` durante a posse da Virtual |
| 40 | Data de Encerramento Virtual | data e hora (Brasil): último encerramento da Virtual na posse (entrada em `Em homologação` ou `SOLN`); vazia se não houver |

Uma linha por chamado. Os blocos e a origem de cada coluna estão em
[virtual-calculation.md, seção 8](virtual-calculation.md#8-mapa-das-colunas);
os nomes revisados em 2026-10-07, na seção 8.1.

As durações saem como texto
`[h]:mm:ss`: horas sem limite
de 24 (`73:21:56`), zero como `0:00:00`. Como são texto, o Power BI não as soma;
os totais de FAIA e FARC vêm das colunas `Indice FAIA` e `Indice FARC`, que são
numéricas e calculadas em segundos dentro do motor, antes da formatação. Não há
coluna numérica auxiliar de duração na saída.

Os tempos contam só as janelas de posse da Virtual, a partir da primeira
entrada no grupo (ver
[virtual-calculation.md, seção 7.1](virtual-calculation.md#71-janelas-de-posse-da-virtual)).
`Tsol (h)` conta só os status ativos (`Em andamento`, `Aberto, aguarda
atendimento` e `Reaberto`); o tempo de posse em `Aguarda atendimento`,
`Agendado`, depois de uma solução registrada e nos demais status de espera sai
em `Tempo Parada Contagem NMS (h)` (seção 7.2). `Tini (h)` e
`Data/Hora Início Atendimento` são os do primeiro atendimento, congelados.

`Grupo` é o grupo do chamado no instante de referência, pelo histórico de
transferências: com `FECHAMENTO`, o grupo no fechamento (sempre a Virtual,
porque é o critério do escopo); com `RESOLUCAO`, o grupo na resolução.

Para separar por Contagem, filtre `Contagem`; por serviço ou objeto atendido,
use `Item de Configuração` e `Categoria`. Para o total de FAIA ou FARC de um
mês, some `Indice FAIA` ou `Indice FARC`, filtrando o mês da data escolhida em
`@DataReferencia`. O abatimento financeiro por item contratual está fora do
escopo ([virtual-calculation.md, seção 11](virtual-calculation.md#11-fora-do-escopo)).

## 6. Conferência

Com o mesmo período, a consulta do Power BI tem as mesmas linhas e os mesmos
valores da referência com a mesma `@DataReferencia`. Na janela de 01/10/2025 a
07/10/2026: 282 chamados com `FECHAMENTO`, nenhuma diferença nas 40 colunas
(SQL da referência, SQL do Power BI e `.m` executado no motor do Power BI
Desktop, em 2026-10-07). A
janela do Power BI vai até amanhã; um chamado fechado hoje aparece nele e não
numa referência que termine hoje à 00:00.

Para conferir, troque no arquivo do Power BI as duas linhas que calculam
`@DataInicio` e `@DataFim` por datas fixas iguais às da referência.

A planilha `analysis/virtual-query-report-analysis.xlsx` pode ser usada para
reconciliar os SDMs do resultado SQL com os relatórios da Virtual. Ela não
interfere nos cálculos nem na população da consulta.

## 7. Migração de Chamados_TCU e Chamados_24x7

Os nomes desta seção são os de 2026-10-06. Na migração, use os nomes atuais da
seção 7.1 (`Contagem` no lugar de `Tipo SLA`, `Prioridade` no lugar de
`Severidade`).

Até 2026-10-06 o painel tinha duas consultas: `Chamados_TCU` (regime TCU) e
`Chamados_24x7` (regime 24x7). Eram o mesmo motor, com o filtro final
`Aba = 'Chamados_TCU'` ou `'Chamados_24x7'`, e cada chamado tinha um único
regime. A consulta única devolve a **união exata** das duas.

Conferência da unificação (2026-10-06, mesmas janelas, contra as consultas
antigas):

| Modo | Chamados_TCU | Chamados_24x7 | Em comum | Consulta única | Duplicados | Diferenças |
|---|---|---|---|---|---|---|
| `FECHAMENTO` | 264 | 12 | 0 | 276 | 0 | 0 nas 40 colunas |
| `RESOLUCAO` | 281 | 12 | 0 | 293 | 0 | 0 nas 40 colunas |

Todos os chamados de `Chamados_24x7` saem com `Tipo SLA = Corrida` e todos os
de `Chamados_TCU` com `Tipo SLA = Comercial`. A matriz Severidade × Tipo SLA
segue a regra (P1 e P2 `Corrida`; P3, P4 e P5 `Comercial`).

Mudanças de coluna (mesma posição, mesmo conteúdo):

| # | Antes | Depois | O que muda no valor |
|---|---|---|---|
| 2 | `Descrição do Chamado` | `Resumo` | nada (mesmo texto) |
| 4 | `Prioridade` (número 1 a 5) | `Severidade` | rótulo da Decision: `1` → `1 - Máxima` ... `5` → `5 - Mínima` |
| 5 | `Regime` (`24x7` / `TCU`) | `Tipo SLA` | `24x7` → `Corrida`, `TCU` → `Comercial` |

Nenhuma coluna foi removida nem acrescentada; `chave` continua igual
(`Incidente|3|TCU`). Passos no PBIX, **uma vez**:

1. Criar a consulta nova com `powerbi/consulta_virtual_chamados_power_bi.m`
   (seção 3), chamada, por exemplo, `Chamados`.
2. Nos visuais e medidas que usavam `Chamados_TCU` ou `Chamados_24x7`, apontar
   para `Chamados`, com filtro `Tipo SLA = Comercial` ou `Tipo SLA = Corrida`
   onde o visual era de um regime só.
3. Trocar as referências às colunas renomeadas: `Descrição do Chamado` →
   `Resumo`, `Prioridade` → `Severidade` (texto; filtros numéricos passam a
   usar o rótulo), `Regime` → `Tipo SLA`.
4. Excluir as consultas `Chamados_TCU` e `Chamados_24x7` do modelo.

### 7.1 Renomeações de 2026-10-07 (revisão contratual)

Mesmo motor, colunas na terminologia do Anexo VII. No PBIX, trocar as
referências:

| # | Antes | Depois | O que muda no valor |
|---|---|---|---|
| 4 | `Severidade` (`3 - Média`) | `Prioridade` | número `3` |
| 5 | `Tipo SLA` (`Corrida` / `Comercial`) | `Contagem` | `24x7` / `Horário TCU` |
| 12–15 | `Horas Comerciais ...` / `Horas Não Comerciais ...` | `Horas Horário TCU ...` / `Horas Fora Horário TCU ...` | na Contagem `24x7` passam a mostrar a divisão real (antes 0 e o total) |
| 20 | `chave` com `TCU` | `chave` com `Horário TCU` | `Solicitação\|3\|Horário TCU` |
| 31 | `Tempo suspenso` | `Tempo Parada Contagem NMS (h)` | nada |
| 37 | `Meta Atendimento` | `Situação Meta Resolução` | nada |

Mesma quantidade de colunas (40), mesma posição. Tempos, excessos, metas e
índices não mudaram.

## 8. Cuidados

- A consulta cria só tabelas temporárias (`#Virt_*`). Não grava nada no banco.
- Os feriados vêm do arquivo de feriados no SharePoint ([feriados.md](feriados.md)).
  Os pontos facultativos de cada ano novo precisam ser cadastrados nele; os
  feriados fixos (`MM-DD`) já valem todo ano. Não é preciso mudar o SQL nem
  republicar o relatório.
- Com `FECHAMENTO`, só entram chamados já fechados: um chamado resolvido e
  ainda não fechado aparece no mês em que for fechado. Com `RESOLUCAO`, ele
  aparece no mês da resolução.
