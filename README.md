# Extração de dados — Virtual

Consultas SQL e documentação da apuração de **FAIA** e **FARC** do fornecedor
**Virtual**, a partir da base do **CA Service Desk Manager** (`mdb`).

A consulta lê só o SDM e entrega os chamados da Virtual em duas grades, por
regime: `Chamados_TCU` e `Chamados_24x7`. A contagem de tempo segue a
arquitetura de posse da Decision; metas, fatores, regime e calendário são os da
Virtual e ficam no próprio SQL. Não há dependência de arquivo externo.

Este repositório atende **somente a Virtual**. Decision, A2B/Protect4 e COI têm
repositórios próprios.

## Estrutura

```text
.
├── analysis/
│   └── virtual-query-report-analysis.xlsx          conferência Consulta x Relatório
├── queries/
│   └── consulta_virtual_faia_farc.sql              consulta de referência
├── powerbi/
│   ├── consulta_virtual_chamados_tcu_power_bi.sql  aba Chamados_TCU
│   └── consulta_virtual_chamados_24x7_power_bi.sql aba Chamados_24x7
├── docs/
│   ├── virtual-calculation.md                      regras de cálculo
│   └── powerbi-query.md                            consultas do Power BI
├── project-context/
│   └── VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md        contexto de manutenção
├── support/                                        consultas auxiliares de investigação
└── README.md
```

## Consulta de referência

[`queries/consulta_virtual_faia_farc.sql`](queries/consulta_virtual_faia_farc.sql)
devolve dois resultados, com as mesmas 40 colunas:

| Resultado | Conteúdo |
|---|---|
| 1 | `Chamados_TCU`: todos os chamados elegíveis do regime TCU |
| 2 | `Chamados_24x7`: todos os chamados elegíveis do regime 24x7 |

Parâmetros no topo do arquivo:

| Parâmetro | Uso |
|---|---|
| `@DataInicio` | início do período, inclusivo (horário do Brasil) |
| `@DataFim` | fim do período, **exclusivo** |
| `@DataReferencia` | `N'FECHAMENTO'` (padrão) ou `N'RESOLUCAO'`: qual data define o período |

`@DataReferencia` escolhe o marco da apuração. Para trocar, mude só essa
linha; nenhum cálculo muda. Outro valor interrompe a consulta com erro.

| Modo | Período por | Exige | Responsabilidade da Virtual validada em |
|---|---|---|---|
| `FECHAMENTO` | `close_date` | fechamento | fechamento (encerrou na Virtual) |
| `RESOLUCAO` | `resolve_date` | resolução (`close_date` pode estar vazio) | instante da resolução (dentro de uma janela de posse) |

Para um mês inteiro,
use o dia 1 do mês e o dia 1 do mês seguinte, por exemplo `2026-07-01` e
`2026-08-01`. Nunca use `23:59:59`.

Em resumo:

- **Escopo:** chamados I/R do período. Em `FECHAMENTO`: fechados, em status
  terminal, com grupo atual `Fornecedores - Virtual` e que encerraram na
  Virtual (última transferência de grupo foi uma entrada na Virtual, ou
  nasceram nela sem transferência). Em `RESOLUCAO`: resolvidos dentro de uma
  janela de posse da Virtual, fechados ou não.
- **Regime:** TCU ou 24x7, pela combinação Tipo + Prioridade.
- **Posse:** o relógio começa na primeira entrada na Virtual (na abertura, se
  o chamado nasceu nela), para nas saídas e volta nas reentradas; todas as
  janelas de posse são somadas.
- **Tempos (modelo da Decision):** `Tini (h)` é o Tempo Primeiro Atendimento:
  tempo de posse até o primeiro `Em andamento` dentro da posse (sem ele, a
  primeira atividade registrada na posse; sem atividade, a entrada). `Tsol (h)`
  é o Tempo de Atendimento: tempo de posse até a resolução, contando só os
  status ativos `Em andamento` e `Aberto, aguarda atendimento`, como no Tempo de
  Atendimento da Decision; os demais (`Aguarda atendimento`, `Agendado`,
  `Reaberto`, solução registrada...) pausam e vão para `Tempo suspenso`.
  `Excesso Resposta (h)` e `Excesso Resolução (h)` correspondem ao Primeiro
  Atendimento Excedido e ao Tempo Atendimento Excedido da Decision.
- **Colunas:** identificação e datas (com `Data/Hora Fechamento`), as 15
  colunas de apuração da Virtual e colunas de contexto no padrão da Decision,
  entre elas `Item de Configuração` e `Categoria`, que identificam o serviço ou
  o objeto atendido. `Grupo` (coluna 38) é o grupo atual do chamado no SDM
  (`call_req.group_id`); é informativa e não é a posse histórica da Virtual.
  `Tempo suspenso` é o tempo de posse até a resolução em status que pausam;
  `Tsol` + `Tempo suspenso` = posse total até a resolução. As durações saem como
  `[h]:mm:ss`; fatores e índices são numéricos e calculados em segundos.
- **Indicadores (`Sim`/`Não`):** `Indicador Reabertura` diz se o chamado foi
  reaberto em algum momento (mesma regra da Decision). `Indicador de
  Agendamento` (coluna 39) diz se o chamado passou para `Agendado` durante a
  posse da Virtual. Os dois são informativos: não mudam tempos, excessos nem
  índices. Reabertura não é tempo ativo: o status `Reaberto` pausa o `Tsol`.
- **Data de Encerramento Virtual (última coluna, 40):** o último encerramento
  da atuação da Virtual durante a posse, por entrada em `Em homologação` ou por
  `SOLN` (solução registrada), como a Data de Encerramento Decision. Com
  reabertura, vale o encerramento do último ciclo. Vazia quando não há esse
  evento. Não é o fechamento (`close_date`) nem substitui a
  `Data/Hora Resolução`, que continua sendo o marco dos tempos.
- **Horário comercial (TCU):** 08:00–20:00, segunda a sexta, fora do
  calendário TCU.

A regra completa está em [`docs/virtual-calculation.md`](docs/virtual-calculation.md).

Execute o arquivo **inteiro** na base `mdb`. A consulta só cria tabelas
temporárias.

## Consultas do Power BI

| Arquivo | Saída |
|---|---|
| [`powerbi/consulta_virtual_chamados_tcu_power_bi.sql`](powerbi/consulta_virtual_chamados_tcu_power_bi.sql) | `Chamados_TCU`, com as mesmas 40 colunas da referência |
| [`powerbi/consulta_virtual_chamados_24x7_power_bi.sql`](powerbi/consulta_virtual_chamados_24x7_power_bi.sql) | `Chamados_24x7`, com as mesmas 40 colunas da referência |

O período é automático: os últimos `@CoberturaMeses` meses (padrão **12**) mais
o mês corrente, pela data escolhida em `@DataReferencia` (padrão `FECHAMENTO`),
declarada no topo de cada arquivo.

O bloco de cálculo (`MOTOR VIRTUAL`) é idêntico nos três arquivos. Mudanças de
regra são feitas na referência e copiadas para os dois arquivos do Power BI.
Detalhes em [`docs/powerbi-query.md`](docs/powerbi-query.md).

## Manutenção anual

O calendário TCU (feriados e pontos facultativos) fica no bloco `[2]` do motor,
tabela `#Virt_Calendario`, e hoje cobre **2025 e 2026**. A cada ano novo, inclua
as datas do ano no bloco da referência e copie o bloco para os dois arquivos do
Power BI.

## Como validar

1. Rode a referência com o período do mês.
2. Confira, por SDM, os marcos (abertura, entrada na Virtual, início,
   resolução, fechamento) e as janelas de posse contra o `act_log` do chamado.
   A consulta `support/consulta_logs_chamados_listados.sql` lista todos os
   logs dos SDMs informados.
3. Para o Power BI, rode as duas consultas com o mesmo período da referência.
   Elas devem ter as mesmas linhas e os mesmos valores dos dois resultados.
4. Para reconciliar com o relatório da Virtual, use
   `analysis/virtual-query-report-analysis.xlsx` (seção *Análise e
   conferência*).

O total de FAIA ou FARC de um período é a soma de `Indice FAIA` ou
`Indice FARC` dos dois resultados (ver `docs/virtual-calculation.md`, seção 9).

## Análise e conferência

A pasta `analysis/` guarda artefatos de validação: comparação dos resultados
das consultas com relatórios externos e reconciliação manual. Não contém SQL e
nada nela é lido pelas consultas.

| Arquivo | Uso |
|---|---|
| `analysis/virtual-query-report-analysis.xlsx` | compara, por período (uma aba por período), os SDMs do relatório da Virtual com os SDMs retornados pela consulta, nos dois sentidos: `Relatório` → `Retorna na consulta?` e `Consulta` → `Tem no relatório?`. A coluna `x` é só um separador |

A planilha é apoio de validação humana. Não é entrada do motor nem fonte
funcional: a população e os cálculos vêm só do SDM.

## Consultas de apoio

| Arquivo | Uso |
|---|---|
| `support/consulta_logs_chamados_listados.sql` | todos os logs dos chamados informados |
| `support/consulta_status_chamados.sql` | status cadastrados no SDM |
| `support/consulta_status_hold.sql` | status e flag `cr_stat.hold` |
| `support/consulta_tipos_chamado.sql` | tipos de chamado e quantidades |

Elas não calculam indicadores. Servem para investigar chamados e conferir códigos.

## Contexto de manutenção

Decisões técnicas, validações feitas e o histórico da engenharia reversa das
planilhas manuais ficam em
[`project-context/VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md`](project-context/VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md).
