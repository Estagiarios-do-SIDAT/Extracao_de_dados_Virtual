# Consultas do Power BI — Virtual

Fonte de dados do painel de FAIA e FARC da Virtual. A regra de cálculo está em
[virtual-calculation.md](virtual-calculation.md).

---

## 1. Arquivos

| Arquivo | Conteúdo |
|---|---|
| `powerbi/consulta_virtual_chamados_tcu_power_bi.sql` | `Chamados_TCU`: todos os chamados elegíveis do regime TCU |
| `powerbi/consulta_virtual_chamados_24x7_power_bi.sql` | `Chamados_24x7`: todos os chamados elegíveis do regime 24x7 |

Cada arquivo devolve **um único resultado**, como o Power BI espera.

## 2. Mesmo motor da consulta de referência

A referência é [`queries/consulta_virtual_faia_farc.sql`](../queries/consulta_virtual_faia_farc.sql).
Os três arquivos têm o mesmo bloco de cálculo, delimitado por:

```text
-- >>> MOTOR VIRTUAL
...
-- <<< MOTOR VIRTUAL
```

O bloco é **idêntico byte a byte** nos três arquivos. SHA256 do bloco, com fim de
linha LF:

```text
265dcbd07712839dff5b426f2a6e05bc3c8acfef55e91ac936cc8625b5c09519
```

Ele recebe só `@DataInicio`, `@DataFim` e `@DataReferencia` e entrega a
tabela `#Virt_Saida`, com os dois regimes. Os arquivos diferem apenas em:

| | Referência | Power BI |
|---|---|---|
| Período | `@DataInicio` / `@DataFim` digitados | calculado a partir de hoje (seção 4) |
| Saída | dois resultados (TCU e 24x7) | um arquivo por regime |

As três consultas têm as mesmas 38 colunas, na mesma ordem.

Qualquer mudança de regra é feita no bloco da referência e copiada para os dois
arquivos do Power BI. Depois da cópia, os três blocos devem continuar idênticos.

## 3. Como usar no Power BI

1. Obter dados → **SQL Server**.
2. Servidor do SDM, banco `mdb`, modo **Importação**.
3. Em *Opções avançadas → Instrução SQL*, colar o arquivo **inteiro**.
4. Deixar *Incluir colunas de relação* desmarcado.
5. Repetir para o outro arquivo. São duas consultas no modelo, uma por regime.

## 4. Período

No topo de cada arquivo:

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
de hoje, pela data escolhida. Com `12`, ela traz os doze meses anteriores, inteiros, e
o mês corrente até hoje. Para outra cobertura, troque só esse número (em
*Etapas aplicadas → Fonte*). Nenhuma regra depende dele.

Exemplo: atualizado em 15/10/2026, com `12` e `FECHAMENTO`, traz chamados
fechados de 01/10/2025 até 15/10/2026.

Volume e tempo de referência (janela de 01/10/2025 a 05/10/2026): 275 chamados
com `FECHAMENTO` (263 TCU, 12 24x7), em 1 a 2 segundos por consulta; 293 com
`RESOLUCAO` (281 TCU, 12 24x7), em cerca de 50 segundos na consulta TCU, porque o
modo lê o `act_log` de todos os chamados resolvidos na janela.

## 5. Saída

As mesmas 38 colunas da referência, na mesma ordem:

| # | Coluna | Unidade |
|---|---|---|
| 1 | ID Chamado | texto |
| 2 | Descrição do Chamado | texto |
| 3 | Tipo (Incidente/Solicitação) | texto |
| 4 | Prioridade | 1 a 5 |
| 5 | Regime | `TCU` / `24x7` |
| 6 | Data/Hora Abertura | data e hora (Brasil) |
| 7 | Data/Hora Início Atendimento | data e hora (Brasil) |
| 8 | Data/Hora Resolução | data e hora (Brasil) |
| 9 | **Data/Hora Fechamento** | data e hora (Brasil) |
| 10 | Tini (h) | texto `[h]:mm:ss` |
| 11 | Tsol (h) | texto `[h]:mm:ss` |
| 12 | Horas Comerciais Resposta (h) | texto `[h]:mm:ss` |
| 13 | Horas Não Comerciais Resposta (h) | texto `[h]:mm:ss` |
| 14 | Horas Comerciais Resolução (h) | texto `[h]:mm:ss` |
| 15 | Horas Não Comerciais Resolução (h) | texto `[h]:mm:ss` |
| 16 | Meta Resposta (h) | texto `[h]:mm:ss` |
| 17 | Meta Resolução (h) | texto `[h]:mm:ss` |
| 18 | Excesso Resposta (h) | texto `[h]:mm:ss` |
| 19 | Excesso Resolução (h) | texto `[h]:mm:ss` |
| 20 | chave | `Tipo\|Prioridade\|Regime` |
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
| 31 | Tempo suspenso | texto `[h]:mm:ss` (posse em status que pausam) |
| 32 | Meta Primeiro Atendimento | `Atende` / `Não Atende` / `N/A` |
| 33 | Indicador Reabertura | `Sim` / `Não` |
| 34 | Acordo Prazo | `-` |
| 35 | Acordo Qualidade | `-` |
| 36 | Justificativa | `-` |
| 37 | Meta Atendimento | `Atende` / `Não Atende` / `N/A` |
| 38 | Grupo | texto: grupo atual do chamado no SDM (vazio sem grupo) |

Uma linha por chamado. Os blocos e a origem de cada coluna estão em
[virtual-calculation.md, seção 8](virtual-calculation.md#8-mapa-das-colunas).

As durações (as 10 do bloco B e `Tempo suspenso`) saem como texto
`[h]:mm:ss`: horas sem limite
de 24 (`73:21:56`), zero como `0:00:00`. Como são texto, o Power BI não as soma;
os totais de FAIA e FARC vêm das colunas `Indice FAIA` e `Indice FARC`, que são
numéricas e calculadas em segundos dentro do motor, antes da formatação. Não há
coluna numérica auxiliar de duração na saída.

Os tempos contam só as janelas de posse da Virtual, a partir da primeira
entrada no grupo (ver
[virtual-calculation.md, seção 7.1](virtual-calculation.md#71-janelas-de-posse-da-virtual)).
`Tsol (h)` conta só os status ativos; o tempo de posse em `Aguarda atendimento`,
`Agendado`, `Reaberto`, depois de uma solução registrada e nos demais status de
espera sai em `Tempo suspenso` (seção 7.2).

`Grupo` é o grupo atual do chamado no SDM (`call_req.group_id`), só para
análise: não é a posse histórica da Virtual. No modo `RESOLUCAO` pode trazer
outro grupo, quando o chamado foi resolvido na Virtual e depois transferido.

Os chamados vêm todos juntos. Para separar por serviço ou objeto atendido,
use os campos do próprio chamado, como `Item de Configuração` e `Categoria`.
Para o total de FAIA ou FARC de um mês, some `Indice FAIA` ou `Indice FARC`
das duas consultas, filtrando o mês da data escolhida em `@DataReferencia`.

## 6. Conferência

Com o mesmo período, as duas consultas do Power BI têm as mesmas linhas e os
mesmos valores dos dois resultados da referência com a mesma
`@DataReferencia`. Conferido em maio/2026 (19 chamados com `FECHAMENTO`, 23 com
`RESOLUCAO`) e na janela de 12 meses até 05/10/2026 (275 com `FECHAMENTO`, 293
com `RESOLUCAO`): nenhuma diferença nas 38 colunas.

Para conferir, troque no arquivo do Power BI as duas linhas que calculam
`@DataInicio` e `@DataFim` por datas fixas iguais às da referência.

A planilha `analysis/virtual-query-report-analysis.xlsx` pode ser usada para
reconciliar os SDMs do resultado SQL com os relatórios da Virtual. Ela não
interfere nos cálculos nem na população da consulta.

## 7. Cuidados

- A consulta cria só tabelas temporárias (`#Virt_*`). Não grava nada no banco.
- O calendário embutido vai até 31/12/2026 e precisa ser atualizado a cada ano
  no bloco `[2]` do motor, na referência, e depois copiado para os dois
  arquivos do Power BI (ver
  [virtual-calculation.md, seção 10](virtual-calculation.md#10-cuidados-e-limitações)).
  Com a janela de 12 meses, a partir de janeiro de 2027 parte da janela fica
  fora do calendário até essa atualização.
- Só entram chamados já fechados. Um chamado resolvido e ainda não fechado
  aparece no mês em que for fechado.
