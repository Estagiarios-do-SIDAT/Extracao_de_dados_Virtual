# Consulta do Power BI — Virtual TI

Fonte de dados do painel de FAIA e FARC da Virtual TI. A regra de cálculo está
em [`docs/virtual-calculation.md`](../docs/virtual-calculation.md): metas,
fatores e Contagem do Edital PE 90028/2025, Anexo VII (fonte oficial:
<https://comprasnet.gov.br/ConsultaLicitacoes/download/download_editais_detalhe.asp?coduasg=30001&modprp=5&numprp=900282025>);
Primeiro Atendimento, Tempo Primeiro Atendimento e Tempo de Atendimento pela
mecânica operacional preservada. Versão resumida, para o visual HTML Content:
[`documentacao-powerbi-virtual.html`](documentacao-powerbi-virtual.html).

---

## 1. Arquivos

| Arquivo | Papel |
|---|---|
| [`powerbi/consulta_virtual_ti_power_bi.m`](consulta_virtual_ti_power_bi.m) | **a consulta do Power BI** (a única): Power Query M que lê o `feriados.txt` no SharePoint, valida, monta `@Feriados` e executa o SQL. É o arquivo que se cola no Editor Avançado |
| [`queries/consulta_virtual_ti_faia_farc.sql`](../queries/consulta_virtual_ti_faia_farc.sql) | **consulta de referência** e fonte do `.m`. Executada pelo `tools/executar_consulta.ps1` para testes e conferências; não se cola no Power BI |
| [`powerbi/documentacao-powerbi-virtual.html`](documentacao-powerbi-virtual.html) | documentação resumida para o visual HTML Content |

Não existe mais um SQL separado para o Power BI. O `.m` é gerado a partir da
consulta de referência:

```text
queries/consulta_virtual_ti_faia_farc.sql   (referência: período fixo + período do Power BI comentado)
        │  tools/gerar_powerbi_m.ps1
        ▼
powerbi/consulta_virtual_ti_power_bi.m      (Power BI: período móvel, feriados do SharePoint)
```

O gerador tira do SQL o bloco `PERIODO REFERENCIA` (datas digitadas) e ativa o
bloco `PERIODO POWER BI` (janela móvel, comentado na referência). O resto — o
bloco de cálculo `MOTOR VIRTUAL_TI` e o `SELECT` final — é o mesmo texto nos
dois usos, então referência e Power BI não podem divergir. O
`tools/verificar_feriados.ps1` acusa `.m` desatualizado.

Para gerar de novo (depois de qualquer mudança no SQL):

```powershell
.\tools\gerar_powerbi_m.ps1 -Consulta .\queries\consulta_virtual_ti_faia_farc.sql -Saida .\powerbi\consulta_virtual_ti_power_bi.m
```

SHA256 do bloco `MOTOR VIRTUAL_TI` (fim de linha LF), para conferência:
`b4a9fb90720c7c2898926755987c7e0b92a9a63b2e203a5767cac0b2ed6f446d`.

## 2. Como usar no Power BI

1. *Página Inicial → Nova Fonte → Consulta Nula → Editor Avançado*.
2. Colar `powerbi/consulta_virtual_ti_power_bi.m` **inteiro**.
3. Preencher `SharePointFeriadosUrl` (seção 6).
4. Credenciais e privacidade (seção 6).

É uma consulta só no modelo, com um resultado (as duas Contagens juntas). Para
separar as Contagens no relatório, filtre pela coluna `Contagem`.

## 3. Período

No bloco `PERIODO POWER BI` (no `.m`, no início do texto `SqlTexto`):

```sql
DECLARE @CoberturaMeses int = 12;
DECLARE @DataReferencia nvarchar(20) = N'FECHAMENTO';
```

| `@DataReferencia` | Data que define o período | Coluna usada |
|---|---|---|
| `N'FECHAMENTO'` (padrão) | fechamento | `Data/Hora Fechamento` (`call_req.close_date`) |
| `N'RESOLUCAO'` | resolução | `Data/Hora Resolução` (`call_req.resolve_date`) |

Com `FECHAMENTO`, entram chamados fechados no período e encerrados na Virtual
TI. Com `RESOLUCAO`, entram chamados resolvidos no período dentro de uma janela
de posse da Virtual TI, mesmo que ainda não tenham fechamento. Trocar só essa
linha muda quais chamados entram; nenhum cálculo muda. Regra completa em
[`docs/virtual-calculation.md`, seção 2](../docs/virtual-calculation.md#2-escopo-e-período).

A janela vai do **dia 1 do mês (corrente − `@CoberturaMeses`)** até o fim do dia
de hoje. Com `12`, traz os doze meses anteriores, inteiros, e o mês corrente
até hoje (ex.: atualizado em 15/10/2026, traz de 01/10/2025 a 15/10/2026). Para
outra cobertura, troque só esse número (no repositório, no bloco
`PERIODO POWER BI` da referência, gerando o `.m` de novo).

Volume de referência (janela de 01/10/2025 a 07/10/2026): 282 chamados com
`FECHAMENTO`; com `RESOLUCAO` a consulta é mais lenta, porque lê o `act_log` de
todos os chamados resolvidos na janela.

## 4. Saída

40 colunas, uma linha por chamado:

| # | Coluna | Conteúdo |
|---|---|---|
| 1 | ID Chamado | texto |
| 2 | Resumo | `call_req.summary` |
| 3 | Tipo (Incidente/Solicitação) | texto |
| 4 | Prioridade | número 1 a 5 (Tabela 4 do Anexo VII) |
| 5 | Contagem | `24x7` / `Horário TCU` / `N/A` (a "Cobertura" da Tabela 1) |
| 6 | Data/Hora Abertura | data e hora (Brasil) |
| 7 | Data/Hora Início Atendimento | Primeiro Atendimento (congelado) |
| 8 | Data/Hora Resolução | data e hora (Brasil) |
| 9 | Data/Hora Fechamento | data e hora (Brasil) |
| 10 | Tini (h) | Tempo Primeiro Atendimento, `[h]:mm:ss` (congelado) |
| 11 | Tsol (h) | Tempo de Atendimento, `[h]:mm:ss` (posse em status ativo) |
| 12 | Horas Horário TCU Resposta (h) | `[h]:mm:ss` |
| 13 | Horas Fora Horário TCU Resposta (h) | `[h]:mm:ss` |
| 14 | Horas Horário TCU Resolução (h) | `[h]:mm:ss` |
| 15 | Horas Fora Horário TCU Resolução (h) | `[h]:mm:ss` |
| 16 | Meta Resposta (h) | `[h]:mm:ss` |
| 17 | Meta Resolução (h) | `[h]:mm:ss` |
| 18 | Excesso Resposta (h) | `[h]:mm:ss` |
| 19 | Excesso Resolução (h) | `[h]:mm:ss` |
| 20 | chave | `Tipo\|Prioridade\|Contagem` |
| 21 | Fator FARC | decimal |
| 22 | Indice FARC | pontos percentuais |
| 23 | Fator FAIA | decimal |
| 24 | Indice FAIA | pontos percentuais |
| 25 | Status | texto |
| 26 | Categoria | `prob_ctg.sym` da categoria do chamado |
| 27 | Responsável Abertura | texto |
| 28 | Responsável Atendimento | texto |
| 29 | Item de Configuração | texto |
| 30 | Data Entrada Grupo Virtual TI | data e hora (Brasil) |
| 31 | Tempo Parada Contagem NMS (h) | `[h]:mm:ss`: posse até a resolução em status que pausam |
| 32 | Meta Primeiro Atendimento | `Atende` / `Não Atende` / `N/A` |
| 33 | Indicador Reabertura | `Sim` / `Não` |
| 34 | Acordo Prazo | `-` |
| 35 | Acordo Qualidade | `-` |
| 36 | Justificativa | `-` |
| 37 | Situação Meta Resolução | `Atende` / `Não Atende` / `N/A` |
| 38 | Grupo | grupo no instante de referência (valor do SDM, ex.: `Fornecedores - Virtual`) |
| 39 | Indicador de Agendamento | `Sim` / `Não`: passou para `Agendado` durante a posse da Virtual TI |
| 40 | Data de Encerramento Virtual TI | último encerramento da Virtual TI na posse (entrada em `Em homologação` ou `SOLN`); vazia se não houver |

Origem de cada coluna:
[`docs/virtual-calculation.md`, seção 8](../docs/virtual-calculation.md#8-mapa-das-colunas).
As durações saem como texto `[h]:mm:ss`; os totais de FAIA e FARC vêm das
colunas numéricas `Indice FAIA` e `Indice FARC`. Para o total de um mês, some
esses índices filtrando o mês da data escolhida em `@DataReferencia`. O
abatimento financeiro por item contratual (itens 2, 3 e 4) está fora do
escopo.

## 5. Conferência

Com o mesmo período, o `.m` e a consulta de referência têm as mesmas linhas e
os mesmos valores. Para conferir, rode a referência com as datas da janela do
Power BI (`tools/executar_consulta.ps1`). Validado em 2026-10-07: 282 chamados,
40 colunas, 0 diferenças entre a referência com a janela do Power BI e o `.m`
executado no motor do Power BI Desktop.

A planilha `analysis/virtual-query-report-analysis.xlsx` pode ser usada para
reconciliar os SDMs do resultado com os relatórios da Virtual TI. Ela não
interfere nos cálculos nem na população.

## 6. Feriados e SharePoint

O cálculo do Horário TCU é feito no SQL Server, que **não lê** o SharePoint.
A consulta do Power BI (`.m`) lê o calendário `feriados.txt` do SharePoint a
cada atualização, valida todas as linhas, converte as datas para o formato do
SQL (`DD-MM` → `MM-DD`, `DD-MM-AAAA` → `AAAA-MM-DD`) e envia a lista ao SQL no
parâmetro `@Feriados` (JSON). Nenhum texto do arquivo é concatenado no SQL.

**Qual arquivo.** O calendário é o `feriados.txt`, o mesmo para Virtual TI,
Decision e A2B. A cópia versionada é [`docs/feriados.txt`](../docs/feriados.txt)
(as regras de preenchimento estão no próprio arquivo); a do SharePoint é a que
o relatório lê. Mantenha as duas iguais, e também as cópias dos outros
repositórios e de `Documentos e Relatórios/feriados.txt`; o
`tools/verificar_feriados.ps1` confere.

**Onde trocar o link.** Para trocar o endereço do SharePoint, altere apenas
`SharePointFeriadosUrl`. É a primeira linha depois de `let` no `.m`, dentro do
bloco `CONFIGURACAO - SHAREPOINT`; o endereço não aparece em nenhum outro lugar
do arquivo:

```powerquery
SharePointFeriadosUrl = "INSERIR_URL_DO_ARQUIVO_FERIADOS_NO_SHAREPOINT",
```

**PENDENTE DO LINK REAL DO SHAREPOINT.** O endereço definitivo do
`feriados.txt` ainda não foi registrado (2026-10-07: nenhum link do arquivo
foi encontrado nos repositórios nem em `Documentos e Relatórios`). Enquanto o
placeholder estiver no `.m`, a atualização falha com *Preencha
SharePointFeriadosUrl...*. Use o link **direto** do arquivo, no formato
`https://<empresa>.sharepoint.com/sites/<site>/Shared%20Documents/<pasta>/feriados.txt`
(no SharePoint: `...` do arquivo > *Detalhes* > *Caminho*; tirar o final
`?web=1`, se houver; o link de compartilhamento `/:t:/r/...` não serve), o
mesmo nos três relatórios. Ao gerar o `.m` de novo, o placeholder volta: troque
de novo, ou registre o link definitivo no `tools/gerar_powerbi_m.ps1` (único
ponto, comum aos três repositórios).

**Configuração no Power BI.**

- **Privacidade:** SharePoint e SQL Server como **Organizacional**. Com uma das
  fontes Privada ou Pública, ou sem nível definido, o Power Query recusa a
  combinação. Não é preciso (nem recomendado) ignorar os níveis de
  privacidade.
- **Credenciais:** SQL Server como hoje (Windows/gateway); SharePoint com
  *Conta organizacional*.
- **Gateway:** o SQL Server é local e o SharePoint Online é fonte de nuvem; a
  consulta combina as duas e é avaliada no gateway: habilitar *Permitir que as
  fontes de dados de nuvem do usuário sejam atualizadas por este cluster de
  gateway*.
- **Consulta nativa:** no Desktop, aprovar a execução da consulta nativa na
  primeira vez (e a cada mudança do SQL).
- **Formula.Firewall:** a leitura do SharePoint e o SQL ficam num único passo
  (`Fonte`); não separe os passos. `SharePointFeriadosUrl` é só um texto e
  pode ficar no topo.

**Falhas que interrompem a atualização** (com a mensagem e, quando for o caso,
a linha do arquivo): link não preenchido; arquivo inacessível (ex.: 404);
arquivo vazio ou fora de UTF-8; data inexistente (`31-02-2026`); linha que
parece data fora do formato (`2026-04-03`, `3-4-2026`); data repetida; data
fora da seção certa; seção diferente das três do arquivo; arquivo sem nenhuma
data. O relatório nunca é calculado com zero feriados.

**Primeiro refresh (checklist).**

1. Copiar `docs/feriados.txt` para a biblioteca do SharePoint escolhida.
2. Criar a consulta a partir do `.m` (*Nova Fonte > Consulta Nula > Editor
   Avançado*, colar o arquivo inteiro).
3. Trocar o placeholder de `SharePointFeriadosUrl` pelo link direto.
4. Credenciais, privacidade (Organizacional + Organizacional) e gateway, como
   acima.
5. Atualizar no Desktop e conferir número de linhas e totais de FAIA e FARC.
6. Publicar e acompanhar o primeiro refresh agendado no serviço.
7. Teste de manutenção: incluir no SharePoint uma data de teste num dia útil
   recente, atualizar, ver as horas no Horário TCU mudarem, apagar a data e
   atualizar de novo.

O motor do Power BI Desktop desta máquina executou o `.m` com as duas fontes
como Organizacional e o firewall ativo (arquivo servido por HTTP local). O
acesso ao SharePoint Online real, o PBIX, o gateway e o refresh no serviço
ainda dependem do ambiente.

## 7. Histórico de nomes de coluna (para atualizar o PBIX)

| Data | Antes | Depois |
|---|---|---|
| 2026-10-06 | `Chamados_TCU` e `Chamados_24x7` (duas consultas) | uma consulta, com a coluna de Contagem |
| 2026-10-06 | `Descrição do Chamado` | `Resumo` |
| 2026-10-07 | `Severidade` (`3 - Média`) | `Prioridade` (`3`) |
| 2026-10-07 | `Tipo SLA` (`Corrida` / `Comercial`) | `Contagem` (`24x7` / `Horário TCU`) |
| 2026-10-07 | `Horas Comerciais ...` / `Horas Não Comerciais ...` | `Horas Horário TCU ...` / `Horas Fora Horário TCU ...` |
| 2026-10-07 | `Tempo suspenso` | `Tempo Parada Contagem NMS (h)` |
| 2026-10-07 | `Meta Atendimento` | `Situação Meta Resolução` |
| 2026-10-07 | `Data Entrada Grupo Virtual` | `Data Entrada Grupo Virtual TI` |
| 2026-10-07 | `Data de Encerramento Virtual` | `Data de Encerramento Virtual TI` |
| 2026-10-07 | `powerbi/consulta_virtual_chamados_power_bi.m` (e `.sql`) | `powerbi/consulta_virtual_ti_power_bi.m` (sem `.sql` separado) |

Os valores não mudaram (só os nomes), salvo as horas dentro/fora do Horário TCU
dos chamados 24x7, que passaram a mostrar a divisão real em 2026-10-07.

## 8. Cuidados

- A consulta cria só tabelas temporárias (`#Virt_*`). Não grava nada no banco.
- Os pontos facultativos de cada ano novo precisam ser cadastrados no
  `feriados.txt`; os feriados fixos já valem todo ano. Não é preciso mudar o
  SQL nem republicar o relatório.
- Com `FECHAMENTO`, só entram chamados já fechados: um chamado resolvido e
  ainda não fechado aparece no mês em que for fechado. Com `RESOLUCAO`, ele
  aparece no mês da resolução.
