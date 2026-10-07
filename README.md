# Extração de dados — Virtual

Consultas SQL e documentação da apuração de **FAIA** e **FARC** do fornecedor
**Virtual**, a partir da base do **CA Service Desk Manager** (`mdb`).

A consulta lê só o SDM e entrega os chamados da Virtual numa **única tabela**,
com a coluna `Contagem` (`24x7` ou `Horário TCU`) dizendo a janela de contagem
de cada chamado.

**Fonte funcional: o Edital PE 90028/2025 e seus anexos**, em especial o
Anexo VII (Níveis Mínimos de Serviço): metas e cobertura (Tabela 1), fatores
(Tabela 2), marcos T0/T1/T2 (itens 3.1.6 a 3.1.8), Horário TCU e 24x7 (3.1.13 e
3.1.14), suspensão, reclassificação e reabertura (3.4 a 3.8). Parte da técnica
(leitura do `act_log`, janelas de posse) foi reaproveitada da Decision, mas não
é fonte de regra. A rastreabilidade regra → cláusula → SQL está em
[`docs/virtual-calculation.md`](docs/virtual-calculation.md#13-rastreabilidade-contratual).
Os feriados vêm do arquivo de feriados ([`docs/feriados.md`](docs/feriados.md)):
`config/feriados.csv` nas consultas de `queries/` e o mesmo arquivo no
SharePoint no Power BI.

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
│   ├── consulta_virtual_chamados_power_bi.sql      SQL do Power BI (Horário TCU e 24x7)
│   └── consulta_virtual_chamados_power_bi.m        consulta do relatório: feriados do SharePoint + SQL
├── config/
│   └── feriados.csv                                feriados e pontos facultativos (cópia versionada)
├── tools/
│   ├── executar_consulta.ps1                       executa queries/ com os feriados do arquivo
│   ├── gerar_powerbi_m.ps1                         gera powerbi/*.m a partir do .sql
│   ├── verificar_feriados.ps1                      valida o arquivo e a sincronia dos repositórios
│   └── feriados.ps1                                leitura e validação do arquivo (uso interno)
├── docs/
│   ├── virtual-calculation.md                      regras de cálculo
│   ├── powerbi-query.md                            consulta do Power BI
│   └── feriados.md                                 arquivo de feriados (igual nos três repositórios)
├── project-context/
│   └── VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md        contexto de manutenção
├── support/                                        consultas auxiliares de investigação
└── README.md
```

## Consulta de referência

[`queries/consulta_virtual_faia_farc.sql`](queries/consulta_virtual_faia_farc.sql)
devolve **um resultado**, com 42 colunas e uma linha por chamado. A coluna
`Contagem` diz a janela de contagem (no Anexo VII, a "Cobertura" da Tabela 1):

| Contagem | Prioridades | Janela (resposta inicial e resolução) | Anexo VII |
|---|---|---|---|
| `24x7` | P1 e P2 | 00:00:00–23:59:59, todos os dias, tempo corrido | 3.1.14 |
| `Horário TCU` | P3, P4 e P5 | 08:00–20:00, segunda a sexta, dias úteis (sem feriados e pontos facultativos) | 3.1.13 |

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
  terminal, cujo grupo **no fechamento** era `Fornecedores - Virtual`, pelo
  histórico de transferências (última transferência de grupo até o fechamento
  foi uma entrada na Virtual, ou nasceram nela sem transferência). Ter passado
  pela Virtual não basta. Em `RESOLUCAO`: resolvidos dentro de uma
  janela de posse da Virtual, fechados ou não.
- **Metas, Contagem e fatores:** Anexo VII, Tabelas 1 e 2, por Tipo +
  Prioridade (bloco `[1]`). A mesma Contagem vale para a resposta inicial e
  para a resolução.
- **Primeiro atendimento (congelado):** `Data/Hora Início Atendimento` e
  `Tini (h)` (Tempo Primeiro Atendimento) não mudaram nesta revisão, por decisão
  do usuário: início = primeiro `Em andamento` dentro da posse da Virtual (sem
  ele, a primeira atividade registrada na posse; sem atividade, a entrada);
  `Tini` = tempo de posse até o início. O Anexo VII define T1 como a
  assinatura do analista no campo "responsável" e a resposta inicial como
  T1 − T0 (3.1.6, 3.1.7); a diferença está documentada em
  `docs/virtual-calculation.md`, seção 4.
- **Resolução (FARC):** `Tsol (h)` conta de **T0** (registro do chamado,
  `Data/Hora Abertura`) até **T2** (`Data/Hora Resolução`), sem os intervalos
  de homologação (`Em homologação` e `Em homologação pelo fiscal`) antes da
  resolução (Anexo VII 3.1.8). Nenhum status suspende a contagem sozinho: o
  contrato só aceita suspensão justificada e com anuência do TCU (3.4.4, 3.6.1),
  e o SDM não registra essa anuência. Reabertura não reinicia a contagem: o
  prazo continua contado da abertura original (3.7.5, 3.8.3).
- **Excesso e índices:** excesso = tempo − meta, quando positivo, por chamado
  (Equações 1 e 4). Na Contagem `Horário TCU` o tempo é o das horas dentro do
  Horário TCU; na `24x7`, o tempo corrido. Índice = horas de excesso × fator
  (Equações 2 e 5). A soma por item, tipo e prioridade (Equações 3 e 6) e o
  arredondamento do somatório em duas casas são da consolidação, fora da
  consulta.
- **Colunas de parada e de apoio à fiscalização:** `Tempo Parada Contagem NMS
  (h)` é o tempo descontado do `Tsol` (homologação antes da resolução; Anexo VII
  6.19.13). `Tempo Agendado (h)` e `Tempo Fora Grupo Virtual (h)` são
  informativos: mostram quanto do `Tsol` o chamado passou em `Agendado` ou fora
  do grupo Virtual. Já estão no `Tsol` e só saem dele se o TCU reconhecer a
  suspensão (3.6.1).
- **Item contratual:** a consulta **não** separa os itens 2, 3 e 4 do Edital
  (conjunto `N` da Tabela 3). O SDM não registra o item, e o Anexo IX liga as
  atividades aos "itens 2 e 3" juntos. Ver `docs/virtual-calculation.md`,
  seção 11 (bloqueio funcional).
- **Colunas:** identificação e datas (com `Data/Hora Fechamento`), as colunas
  de apuração e colunas de contexto: `Resumo` (a breve descrição, 6.19.14),
  `Prioridade` (1 a 5, Tabela 4), `Status`, `Categoria`, os responsáveis pela
  abertura e pelo atendimento, `Item de Configuração`, `Grupo` (grupo no
  instante de referência: fechamento ou resolução), `Situação Meta Resolução`
  e `Meta Primeiro Atendimento` (`Atende`/`Não Atende`). Não há
  `Responsável Resolução` (ver `docs/virtual-calculation.md`, seção 8.1). As
  durações saem como `[h]:mm:ss`; fatores e índices são numéricos e
  calculados em segundos.
- **Indicadores (`Sim`/`Não`):** `Indicador Reabertura` diz se o chamado foi
  reaberto. `Indicador de Agendamento` diz se o chamado passou para `Agendado`
  durante a posse da Virtual. Os dois são informativos: não mudam tempos,
  excessos nem índices.
- **Data de Encerramento Virtual:** o último encerramento da atuação da Virtual
  durante a posse, por entrada em `Em homologação` ou por `SOLN` (solução
  registrada). Coluna informativa, sem equivalente no contrato. Não é o
  fechamento (`close_date`) nem substitui a `Data/Hora Resolução` (T2).
- **Horário TCU:** 08:00–20:00, segunda a sexta, fora dos feriados e pontos
  facultativos do calendário do TCU (arquivo de feriados, o mesmo da Decision e
  da A2B).

A regra completa está em [`docs/virtual-calculation.md`](docs/virtual-calculation.md).

A consulta recebe os feriados pelo parâmetro `@Feriados`, montado a partir de
`config/feriados.csv` pelo script:

```powershell
.\tools\executar_consulta.ps1 -Consulta .\queries\consulta_virtual_faia_farc.sql -Saida C:\temp\virtual
# ou, para abrir no SSMS:
.\tools\executar_consulta.ps1 -Consulta .\queries\consulta_virtual_faia_farc.sql -GerarSql C:\temp\virtual_ssms.sql
```

Aberto direto no SSMS, sem o script, o arquivo falha com *Must declare the
scalar variable "@Feriados"*: a consulta nunca roda sem feriados. Ela só cria
tabelas temporárias. Detalhes em [`docs/feriados.md`](docs/feriados.md).

## Consultas do Power BI

| Arquivo | Saída |
|---|---|
| [`powerbi/consulta_virtual_chamados_power_bi.m`](powerbi/consulta_virtual_chamados_power_bi.m) | consulta do relatório (Power Query M): lê os feriados do SharePoint e executa o SQL abaixo |
| [`powerbi/consulta_virtual_chamados_power_bi.sql`](powerbi/consulta_virtual_chamados_power_bi.sql) | todos os chamados (Horário TCU e 24x7), com as mesmas 42 colunas da referência |

Substitui as antigas `Chamados_TCU` e `Chamados_24x7`, que eram a mesma consulta
com filtros opostos. A migração do PBIX (uma vez) está em
[`docs/powerbi-query.md`](docs/powerbi-query.md#7-migração-de-chamados_tcu-e-chamados_24x7).

O período é automático: os últimos `@CoberturaMeses` meses (padrão **12**) mais
o mês corrente, pela data escolhida em `@DataReferencia` (padrão `FECHAMENTO`),
declarada no topo do arquivo.

O bloco de cálculo (`MOTOR VIRTUAL`) é idêntico na referência e no Power BI.
Mudanças de regra são feitas na referência e copiadas para o arquivo do Power
BI. Detalhes em [`docs/powerbi-query.md`](docs/powerbi-query.md).

## Feriados

Os feriados e pontos facultativos ficam no **arquivo de feriados**, e não no
SQL. É um calendário só, o do TCU (Portarias do TCU de cada ano), igual para
Virtual, Decision e A2B. Para incluir um feriado: editar o `feriados.csv` no
SharePoint e salvar; a próxima atualização do relatório já usa a lista nova,
sem mudar o SQL nem republicar. Manter igual o `config/feriados.csv` dos três
repositórios e conferir com `tools/verificar_feriados.ps1`.

Os feriados nacionais fixos (`MM-DD`) valem todo ano automaticamente. A cada
nova Portaria do TCU, cadastrar só as datas daquele ano (feriados móveis e
pontos facultativos), com a Portaria na coluna `Fonte`. Formato, passo a passo,
falhas, Power BI/SharePoint, privacidade e gateway em
[`docs/feriados.md`](docs/feriados.md).

## Como validar

1. Rode a referência com o período do mês, pelo `tools/executar_consulta.ps1`.
2. Confira, por SDM, os marcos (abertura, entrada na Virtual, início,
   resolução, fechamento) e as janelas de posse contra o `act_log` do chamado.
   A consulta `support/consulta_logs_chamados_listados.sql` lista todos os
   logs dos SDMs informados.
3. Para o Power BI, rode a consulta com o mesmo período da referência. Ela
   deve ter as mesmas linhas e os mesmos valores.
4. Para reconciliar com o relatório da Virtual, use
   `analysis/virtual-query-report-analysis.xlsx` (seção *Análise e
   conferência*).

O total de FAIA ou FARC de um período é a soma de `Indice FAIA` ou
`Indice FARC` do resultado, Horário TCU e 24x7 juntos, por item contratual
quando o item puder ser identificado (ver `docs/virtual-calculation.md`,
seções 9 e 11).

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
