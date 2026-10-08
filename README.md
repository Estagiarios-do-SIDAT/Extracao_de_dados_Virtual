# Extração de dados — Virtual TI

Consultas SQL e documentação da apuração de **FAIA** e **FARC** do fornecedor
**Virtual TI**, a partir da base do **CA Service Desk Manager** (`mdb`).

A consulta lê só o SDM e entrega os chamados da Virtual TI numa **única
tabela**, com a coluna `Contagem` (`24x7` ou `Horário TCU`) dizendo a janela
de contagem de cada chamado.

**Regra contratual:** o Edital PE 90028/2025 (Anexo VII) define as metas por
Tipo + Prioridade, os fatores FAIA e FARC, a cobertura (Contagem: 24x7 e
Horário TCU) e a terminologia. **Mecânica operacional preservada:** Primeiro
Atendimento, Tempo Primeiro Atendimento e Tempo de Atendimento seguem a lógica
operacional consolidada na Decision e adaptada à posse da Virtual TI (a mesma
da versão publicada `15dbe62`), e não a leitura literal dos marcos T0/T1/T2 do
Anexo VII; o Tempo de Atendimento não conta desde a abertura do chamado. A
rastreabilidade está em
[`docs/virtual-calculation.md`](docs/virtual-calculation.md#13-rastreabilidade).

Fonte oficial do pacote de Edital e anexos (PE 90028/2025, Comprasnet):
<https://comprasnet.gov.br/ConsultaLicitacoes/download/download_editais_detalhe.asp?coduasg=30001&modprp=5&numprp=900282025>.
Os feriados vêm do calendário [`docs/feriados.txt`](docs/feriados.txt): a
cópia do repositório nas consultas de `queries/` e o mesmo arquivo no
SharePoint no Power BI.

Este repositório atende **somente a Virtual TI** (no SDM, grupo
`Fornecedores - Virtual`). Decision, A2B/Protect4 e COI têm repositórios
próprios.

## Estrutura

```text
.
├── analysis/
│   └── virtual-query-report-analysis.xlsx          conferência Consulta x Relatório
├── queries/
│   └── consulta_virtual_ti_faia_farc.sql           consulta de referência (e fonte do .m)
├── powerbi/
│   ├── consulta_virtual_ti_power_bi.m              A consulta do Power BI (única; gerada da referência)
│   ├── powerbi-query.md                            documentação do Power BI (SharePoint, período, colunas)
│   └── documentacao-powerbi-virtual.html           documentação resumida (visual HTML Content)
├── tools/
│   ├── executar_consulta.ps1                       executa queries/ com os feriados do arquivo
│   ├── gerar_powerbi_m.ps1                         gera powerbi/*.m a partir do SQL de referência
│   ├── verificar_feriados.ps1                      valida o calendário, a sincronia e se o .m está em dia
│   └── feriados.ps1                                leitura e validação do calendário (uso interno)
├── docs/
│   ├── virtual-calculation.md                      regras de cálculo e rastreabilidade
│   └── feriados.txt                                calendário de feriados e pontos facultativos (igual na Virtual TI, Decision e A2B)
├── project-context/
│   └── VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md        contexto de manutenção
├── support/                                        consultas auxiliares de investigação
└── README.md
```

## Consulta de referência

[`queries/consulta_virtual_ti_faia_farc.sql`](queries/consulta_virtual_ti_faia_farc.sql)
devolve **um resultado**, com 41 colunas e uma linha por chamado. A coluna
`Contagem` diz a janela de contagem (no Anexo VII, a "Cobertura" da Tabela 1):

| Contagem | Prioridades | Janela (resposta inicial e resolução) | Anexo VII |
|---|---|---|---|
| `24x7` | P1 e P2 | 00:00:00–23:59:59, todos os dias, tempo corrido | 3.1.14 |
| `Horário TCU` | P3, P4 e P5 | 08:00–20:00, segunda a sexta, dias úteis (sem feriados e pontos facultativos) | 3.1.13 |

Parâmetros no bloco `PERIODO REFERENCIA`, no topo do arquivo:

| Parâmetro | Uso |
|---|---|
| `@DataInicio` | início do período, inclusivo (horário do Brasil) |
| `@DataFim` | fim do período, **exclusivo** |
| `@DataReferencia` | `N'FECHAMENTO'` (padrão) ou `N'RESOLUCAO'`: qual data define o período |

`@DataReferencia` escolhe o marco da apuração. Para trocar, mude só essa
linha; nenhum cálculo muda. Outro valor interrompe a consulta com erro.

| Modo | Período por | Exige | Responsabilidade da Virtual TI validada em |
|---|---|---|---|
| `FECHAMENTO` | `close_date` | fechamento | fechamento (encerrou na Virtual TI) |
| `RESOLUCAO` | `resolve_date` | resolução (`close_date` pode estar vazio) | instante da resolução (dentro de uma janela de posse) |

Para um mês inteiro, use o dia 1 do mês e o dia 1 do mês seguinte, por exemplo
`2026-07-01` e `2026-08-01`. Nunca use `23:59:59`.

Em resumo:

- **Escopo:** chamados I/R do período. Em `FECHAMENTO`: fechados, em status
  terminal, cujo grupo **no fechamento** era `Fornecedores - Virtual` (nome do
  grupo no SDM), pelo histórico de transferências (última transferência de
  grupo até o fechamento foi uma entrada na Virtual TI, ou nasceram nela sem
  transferência). Ter passado pela Virtual TI não basta. Em `RESOLUCAO`:
  resolvidos dentro de uma janela de posse da Virtual TI, fechados ou não.
- **Metas, Contagem e fatores:** Anexo VII, Tabelas 1 e 2, por Tipo +
  Prioridade (bloco `[1]`). A mesma Contagem vale para a resposta inicial e
  para a resolução.
- **Posse:** o relógio começa na primeira entrada na Virtual TI (na abertura,
  se o chamado nasceu nela), para nas saídas e volta nas reentradas; todas as
  janelas de posse são somadas. O tempo em outro grupo não conta.
- **Primeiro atendimento (congelado):** `Data/Hora Início Atendimento` é o
  primeiro `Em andamento` dentro da posse (sem ele, a primeira atividade
  registrada na posse; sem atividade, a entrada); `Tini (h)` (Tempo Primeiro
  Atendimento) é o tempo de posse até ele.
- **Tempo de Atendimento:** `Tsol (h)` é o tempo de posse até a resolução,
  contando só os status ativos `Em andamento`, `Aberto, aguarda atendimento` e
  `Reaberto` (lista explícita, e não `cr_stat.hold`); os demais (`Aguarda
  atendimento`, `Agendado`, solução registrada...) pausam e vão para
  `Tempo Parada Contagem NMS (h)`. `Tempo Total Virtual TI` é a soma dos dois:
  a posse até a resolução, em qualquer status (informativo).
- **Excesso e índices:** excesso = tempo − meta, quando positivo, por chamado.
  Na Contagem `Horário TCU` o tempo é o das horas dentro do Horário TCU; na
  `24x7`, o tempo corrido. Índice = horas de excesso × fator, em pontos
  percentuais.
- **Fora do escopo:** abatimento financeiro por item contratual (itens 2, 3 e 4
  do Edital) e suspensão aprovada pelo TCU (ver
  `docs/virtual-calculation.md`, seção 11).
- **Colunas:** identificação e datas (com `Data/Hora Fechamento`), as colunas
  de apuração e colunas de contexto: `Resumo` (`call_req.summary`),
  `Prioridade` (`1 - Máxima` a `5 - Mínima`, Tabela 4; as metas usam o número), `Status`, `Categoria` (`prob_ctg.sym`), os
  responsáveis pela abertura e pelo atendimento, `Item de Configuração`,
  `Grupo` (grupo no instante de referência: fechamento ou resolução, com o nome
  do SDM), `Situação Meta Resolução` e `Meta Primeiro Atendimento`
  (`Atende`/`Não Atende`). Não há `Responsável Resolução` (ver
  `docs/virtual-calculation.md`, seção 8.1). As durações saem como
  `[h]:mm:ss`; fatores e índices são numéricos e calculados em segundos.
- **Indicadores (`Sim`/`Não`):** `Indicador Reabertura` diz se o chamado foi
  reaberto. `Indicador de Agendamento` diz se o chamado passou para `Agendado`
  durante a posse da Virtual TI. Os dois são informativos: não mudam tempos,
  excessos nem índices.
- **Data de Encerramento Virtual TI:** o último encerramento da atuação da
  Virtual TI durante a posse, por entrada em `Em homologação` ou por `SOLN`
  (solução registrada). Coluna informativa, sem equivalente no contrato. Não é
  o fechamento (`close_date`) nem substitui a `Data/Hora Resolução`.
- **Horário TCU:** 08:00–20:00, segunda a sexta, fora dos feriados e pontos
  facultativos do calendário do TCU (`docs/feriados.txt`, o mesmo da Decision e
  da A2B).

A regra completa está em [`docs/virtual-calculation.md`](docs/virtual-calculation.md).

A consulta recebe os feriados pelo parâmetro `@Feriados`, montado a partir de
`docs/feriados.txt` pelo script:

```powershell
.\tools\executar_consulta.ps1 -Consulta .\queries\consulta_virtual_ti_faia_farc.sql -Saida C:\temp\virtual_ti
# ou, para abrir no SSMS:
.\tools\executar_consulta.ps1 -Consulta .\queries\consulta_virtual_ti_faia_farc.sql -GerarSql C:\temp\virtual_ti_ssms.sql
```

Aberto direto no SSMS, sem o script, o arquivo falha com *Must declare the
scalar variable "@Feriados"*: a consulta nunca roda sem feriados. Ela só cria
tabelas temporárias.

## Consulta do Power BI

A **única** consulta do Power BI é
[`powerbi/consulta_virtual_ti_power_bi.m`](powerbi/consulta_virtual_ti_power_bi.m)
(Power Query M, colado no Editor Avançado). Ela é **gerada** da consulta de
referência pelo `tools/gerar_powerbi_m.ps1`: só o período muda (janela móvel
dos últimos `@CoberturaMeses` meses, padrão 12, mais o mês corrente). Não
existe um SQL separado do Power BI para manter em paralelo.

O `.m` lê o `feriados.txt` pelo conector `SharePoint.Files` (Conta
organizacional, site fixo). A única configuração é `SharePointFeriadosLink`, no
topo do `.m`: o link do arquivo copiado do SharePoint, de onde saem a pasta e o
nome.

Documentação: [`powerbi/powerbi-query.md`](powerbi/powerbi-query.md) (arquivos,
período, colunas, SharePoint, privacidade, gateway, checklist) e
[`powerbi/documentacao-powerbi-virtual.html`](powerbi/documentacao-powerbi-virtual.html)
(resumo para o visual HTML Content).

## Feriados

Os feriados e pontos facultativos ficam no **calendário**
[`docs/feriados.txt`](docs/feriados.txt), e não no SQL. É um calendário só, o
do TCU (Portarias do TCU de cada ano), igual para Virtual TI, Decision e A2B.
O arquivo é texto simples, com duas seções: `## Feriados Fixos` (`DD-MM`, valem
todo ano) e `## Feriados móveis/diferenciados e pontos facultativos`
(`DD-MM-AAAA`, valem só no ano). Regras completas em
[`powerbi/powerbi-query.md`](powerbi/powerbi-query.md), seção 6.

Para incluir um feriado: editar o `feriados.txt` no SharePoint e salvar; a
próxima atualização do relatório já usa a lista nova, sem mudar o SQL nem
republicar. Manter igual o `docs/feriados.txt` dos repositórios
Virtual TI, Decision e A2B e a cópia em
`Documentos e Relatórios/feriados.txt`, e conferir com
`tools/verificar_feriados.ps1`.

## Como validar

1. Rode a referência com o período do mês, pelo `tools/executar_consulta.ps1`.
2. Confira, por SDM, os marcos (abertura, entrada na Virtual TI, início,
   resolução, fechamento) e as janelas de posse contra o `act_log` do chamado.
   A consulta `support/consulta_logs_chamados_listados.sql` lista todos os
   logs dos SDMs informados.
3. Para o Power BI, rode a referência com o mesmo período da janela do
   relatório: as linhas e os valores são os mesmos.
4. Rode `tools/verificar_feriados.ps1`: calendário válido, cópias iguais e `.m`
   em dia com a referência.
5. Para reconciliar com o relatório da Virtual TI, use
   `analysis/virtual-query-report-analysis.xlsx`.

O total de FAIA ou FARC de um período é a soma de `Indice FAIA` ou
`Indice FARC` do resultado, Horário TCU e 24x7 juntos (ver
`docs/virtual-calculation.md`, seção 9). A consulta não calcula abatimento
financeiro por item.

## Análise e conferência

A pasta `analysis/` guarda artefatos de validação: comparação dos resultados
das consultas com relatórios externos e reconciliação manual. Não contém SQL e
nada nela é lido pelas consultas.

| Arquivo | Uso |
|---|---|
| `analysis/virtual-query-report-analysis.xlsx` | compara, por período (uma aba por período), os SDMs do relatório da Virtual TI com os SDMs retornados pela consulta, nos dois sentidos: `Relatório` → `Retorna na consulta?` e `Consulta` → `Tem no relatório?`. A coluna `x` é só um separador |

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
