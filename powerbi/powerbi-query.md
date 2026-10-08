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
3. Conferir `SharePointFeriadosLink`, no topo do `.m`: o link do
   `feriados.txt` oficial no SharePoint, já preenchido (seção 6).
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

O calendário de feriados e pontos facultativos do TCU fica no arquivo
`feriados.txt`, e não no SQL. É o mesmo para Virtual TI, Decision e A2B. Esta
seção é a referência completa do arquivo e da leitura pelo Power BI; o próprio
arquivo traz só um resumo de cinco linhas, para que as datas fiquem logo no
início.

### Para que serve

- **Horário TCU:** conta de segunda a sexta, das 08:00 às 20:00. Cada data do
  calendário sai **inteira** do Horário TCU (não existe meio expediente).
  Sábado e domingo já ficam de fora sem cadastro; por isso a Páscoa, que é
  sempre num domingo, não aparece no arquivo.
- **24x7:** soma todas as horas, inclusive fins de semana, feriados e pontos
  facultativos. O calendário não altera a contagem 24x7.
- **Fonte das datas:** só a Portaria do TCU que "divulga os feriados nacionais e
  define os dias de ponto facultativo" do ano, publicada no Boletim do TCU, e
  todas as Portarias que a alterarem (`pesquisa.apps.tcu.gov.br`, base
  **Normas**; a ficha da Portaria anual lista as alterações em "Alterada por").
  Não entram feriados estaduais, municipais ou de outros órgãos.

### As três seções

| Seção (título literal no arquivo) | O que guarda | Formato | Vale |
|---|---|---|---|
| `## Feriados Fixos` | feriados nacionais que caem sempre no mesmo dia | `DD-MM` | todo ano |
| `## Feriados móveis/diferenciados` | datas que a Portaria classifica como **feriado nacional**, mas cujo dia muda a cada ano (hoje, só a Paixão de Cristo) | `DD-MM-AAAA` | só naquele dia |
| `## Pontos Facultativos` | dias que a Portaria define como **ponto facultativo**: Carnaval, Quarta-Feira de Cinzas, Corpus Christi, emendas, vésperas, Dia do Servidor Público e datas extraordinárias | `DD-MM-AAAA` | só naquele dia |

A seção segue a **classificação da Portaria**, e não o fato de a data mudar de
um ano para outro: Carnaval e Corpus Christi também mudam de data, mas a
Portaria-TCU nº 1/2026, por exemplo, os define como ponto facultativo e a
Paixão de Cristo como feriado nacional. As duas seções com ano têm o mesmo
efeito no cálculo; a separação serve para conferir o arquivo contra a
Portaria.

### Formato do arquivo (contrato de leitura)

O `.m` do Power BI e o `tools/feriados.ps1` (usado pelo
`verificar_feriados.ps1` e pelo `executar_consulta.ps1`) aplicam as mesmas
regras e dão o mesmo resultado para o mesmo arquivo. Cada linha, sem os espaços
das pontas, é classificada assim:

| Linha (exemplo) | Como é lida |
|---|---|
| `## Pontos Facultativos` | título de uma das três seções; maiúsculas, acentos e espaços a mais no nome não importam |
| `## Observações`, `### Notas` | qualquer linha que comece com `##` é título: se o nome não for uma das três seções, **erro** |
| `25-12` | feriado fixo, só em `## Feriados Fixos`; vale para o mesmo dia e mês de todos os anos |
| `04-06-2026` | data com ano, só em `## Feriados móveis/diferenciados` ou `## Pontos Facultativos`; vale só nesse dia |
| `Ano de 2026.`, linha vazia, frase de texto | ignorada |
| `04-06-2026 Corpus Christi` | **ignorada sem erro**: a data fica fora do calendário sem aviso |
| `2026.`, `04/06/2026`, `4-6-2026`, `2026-06-04` | só números e sinais, fora do formato: **erro** |
| `31-04-2026`; data repetida, mesmo em outra seção; data na seção errada | **erro** |

Por isso:

- **escreva cada data sozinha na linha**; um comentário vai na linha de cima;
- **o rótulo de ano começa com a palavra "Ano"** (`Ano de 2027.`). A linha
  `2027.` sozinha interrompe a atualização;
- não renomeie, traduza nem crie títulos de seção;
- salve em **UTF-8** (com ou sem BOM). UTF-16, ou ANSI (Windows-1252) com
  acentos, são rejeitados. Quebras de linha CRLF ou LF funcionam igual;
- o arquivo precisa ter pelo menos uma data;
- um feriado fixo em `29-02` só valeria nos anos bissextos.

Um ano sem nenhuma data com ano cadastrada **não** dá erro: nesse ano só os
feriados fixos saem do Horário TCU, e a Paixão de Cristo e os pontos
facultativos contam como dias úteis. Por isso o ano novo precisa ser cadastrado
assim que a Portaria for publicada.

### Onde ficam as cópias

| Cópia | Quem usa |
|---|---|
| SharePoint, site `EstgioSidatTCU`, biblioteca *Documentos Compartilhados*, pasta `Atividades Avulsas/Indicadores e Relatórios de Serviços/Documentos e Relatórios/` | **o Power BI** (os três relatórios) |
| `docs/feriados.txt` dos repositórios Virtual TI, Decision e A2B | consultas executadas pelo repositório (`tools/executar_consulta.ps1`) e o verificador |
| `Documentos e Relatórios/feriados.txt` (pasta de trabalho, fora do Git) | referência; conferida pelo verificador |

As cópias do repositório e a de `Documentos e Relatórios` devem ser idênticas;
o `tools/verificar_feriados.ps1` confere. **Publicar no GitHub não atualiza o
SharePoint**, e editar no SharePoint não atualiza o repositório: as duas pontas
são atualizadas à mão. O mesmo site também guarda cópias sincronizadas dos
repositórios (`Repositórios/Extracao_de_dados_*/docs/feriados.txt`); o Power BI
não as lê, porque a consulta exige a pasta do link.

### Cadastrar um ano novo ou alterar datas

1. Confirme as datas na Portaria do ano (e nas que a alterarem).
2. Edite o `docs/feriados.txt` de um dos repositórios:
   - **Feriados Fixos:** nada a fazer; já valem para o ano novo (só muda se a
     Portaria criar um feriado nacional fixo novo);
   - nas outras duas seções, acrescente `Ano de AAAA.` e, abaixo, as datas do
     ano, cada uma na seção que a Portaria indicar;
   - Portaria que altere o calendário durante o ano: incluir, corrigir ou
     apagar a data;
   - não cadastre ano futuro antes da Portaria; não apague anos anteriores
     (chamados antigos continuam sendo calculados com eles).
3. Copie o arquivo para o `docs/feriados.txt` dos outros dois repositórios e
   para `Documentos e Relatórios/feriados.txt`.
4. Valide em qualquer um dos repositórios: `.\tools\verificar_feriados.ps1`.
   Ele lê o arquivo com as regras acima, mostra quantas datas há por seção e
   por ano, compara as cópias e confere se o `.m` está em dia.
5. **Substitua o `feriados.txt` na pasta do SharePoint** (mesmo nome, mesma
   pasta) pelo arquivo validado.
6. Atualize o relatório no Power BI. Não é preciso mudar o SQL, gerar o `.m` de
   novo nem republicar o relatório.
7. Registre a Portaria (número e código de autenticidade) no histórico do
   projeto (`project-context/`).

### Como o Power BI lê o calendário

O cálculo do Horário TCU é feito no SQL Server, que não lê o SharePoint. A
consulta do Power BI (`.m`) faz a leitura e entrega a lista ao SQL. A **única
configuração** fica no topo do `.m`, logo abaixo de `let`: o link do
`feriados.txt` copiado do SharePoint (*Copiar link*, ou o endereço com o
arquivo aberto).

```powerquery
SharePointFeriadosLink = "https://tcucloud.sharepoint.com/:t:/r/sites/EstgioSidatTCU/Documentos%20Compartilhados/Atividades%20Avulsas/Indicadores%20e%20Relat%C3%B3rios%20de%20Servi%C3%A7os/Documentos%20e%20Relat%C3%B3rios/feriados.txt?d=w3744a75ddc284a38890b5d9c4af44be3&csf=1&web=1&e=hwfUQM",
```

1. **O link não é aberto.** Ele serve só para identificar o arquivo: o `.m`
   separa o caminho com `Uri.Parts` (o que vem depois de `?` é descartado),
   tira o prefixo de compartilhamento `/:t:/r`, decodifica os `%XX`
   (`%20` → espaço, `%C3%B3` → `ó`...) e obtém a pasta e o nome:

   | Extraído do link | Valor |
   |---|---|
   | Site | `https://tcucloud.sharepoint.com/sites/EstgioSidatTCU` |
   | Pasta | `https://tcucloud.sharepoint.com/sites/EstgioSidatTCU/Documentos Compartilhados/Atividades Avulsas/Indicadores e Relatórios de Serviços/Documentos e Relatórios/` |
   | Nome | `feriados.txt` |

2. **A leitura é feita por `SharePoint.Files`, num site fixo:**

   ```powerquery
   ArquivosSite = SharePoint.Files("https://tcucloud.sharepoint.com/sites/EstgioSidatTCU", [ApiVersion = 15]),
   ```

   O endereço é **literal** (vem do gerador, `tools/gerar_powerbi_m.ps1`), e
   não montado a partir do link: o Power BI Service só agenda a atualização
   de fontes que ele reconhece sem executar a consulta. A credencial é a
   **Conta organizacional**. Um link de outro site, ou de outro domínio, é
   erro; para usar outro site, altere `$SiteConexao` no gerador e gere os `.m`
   de novo.
3. Ficam só os arquivos com o **nome e a pasta** do link (coluna
   `[Folder Path]`; sem diferença de maiúsculas e da barra final). O site tem
   outras cópias com o mesmo nome (dentro de
   `Repositórios/Extracao_de_dados_*/docs/`); por isso a pasta é obrigatória.
   Deve sobrar **exatamente um** arquivo. Nenhum: a atualização falha com a
   lista das pastas do site que têm um arquivo com esse nome. Mais de um: a
   atualização falha. Nunca se escolhe a primeira linha.
4. O conteúdo (`[Content]`) é lido como UTF-8 e validado linha a linha com as
   regras da tabela acima. Qualquer erro, ou nenhuma data, faz a etapa `Fonte`
   falhar com `Feriados: ...` e o número da linha; o SQL nem é executado.
5. A lista vai ao SQL no **parâmetro** `@Feriados`, em JSON (`DD-MM` → `MM-DD`,
   `DD-MM-AAAA` → `AAAA-MM-DD`), por `Value.NativeQuery`. Nada do link nem do
   arquivo é concatenado no SQL. O SQL confere o formato de novo e monta duas
   listas: os dias e meses que valem todo ano e as datas que valem uma vez.

**Quando mexer no link:** só se o `feriados.txt` mudar de pasta ou de nome
(cole o link novo, do mesmo site). Trocar as datas dentro do mesmo arquivo não
exige mudar o Power Query.

**Links que não servem:** o link curto de compartilhamento
(`https://tcucloud.sharepoint.com/:t:/s/<site>/<identificador>`) não traz o
caminho do arquivo, e a consulta recusa (não se adivinha a pasta). O link
nunca é aberto com `Web.Contents`: com ele, o Power BI Desktop recusou a
credencial organizacional.

### Configurar no Power BI Desktop

1. Abra a consulta do relatório no Editor do Power Query e clique em
   *Editor Avançado* (ou, para uma consulta nova: *Página Inicial → Nova
   Fonte → Consulta Nula → Editor Avançado*). Substitua todo o texto pelo
   `.m` inteiro. O `.m` não vai no campo *Instrução SQL*.
2. Confira a linha `SharePointFeriadosLink`: deve ser o link do `feriados.txt`
   oficial (pasta `Documentos e Relatórios`).
3. Credenciais (*Arquivo → Opções e configurações → Configurações da fonte de
   dados*):
   - SharePoint (`https://tcucloud.sharepoint.com/sites/EstgioSidatTCU`, ou a
     raiz do tenant): **Conta organizacional → Entrar**, com o usuário do TCU;
   - SQL Server (`bdados-14r`, `mdb`): a mesma credencial de hoje.
4. Privacidade das duas fontes: **Organizacional** (*Editar permissões* em
   cada uma). Não desative os níveis de privacidade.
5. *Atualizar visualização*. Na primeira vez (e a cada mudança do SQL),
   aprovar a execução da consulta nativa.
6. A consulta só carrega se encontrou exatamente um `feriados.txt` na pasta do
   link e se o arquivo é válido. Se aparecer `Feriados: ...`, a mensagem diz o
   motivo (link, pasta, linha do arquivo).

**Formula.Firewall:** a leitura do SharePoint e o SQL ficam num único passo
(`Fonte`); não separe os passos. `SharePointFeriadosLink` é só texto e pode
ficar no topo.

### Publicar e agendar no Power BI Service

Roteiro para a equipe que publica os relatórios. **Esta configuração ainda não
foi validada no serviço**; só uma atualização real bem-sucedida confirma.

1. **Publicar:** no Power BI Desktop, com a consulta já atualizada sem erro,
   *Página Inicial → Publicar* no workspace do relatório (substituindo o
   conjunto de dados existente).
2. **SharePoint Online:** no serviço, *conjunto de dados (modelo semântico) →
   Configurações → Credenciais da fonte de dados* → fonte SharePoint
   (`https://tcucloud.sharepoint.com/sites/EstgioSidatTCU`) → *Editar
   credenciais*: método **OAuth2**, nível de privacidade **Organizacional**,
   entrar com a conta institucional. A credencial é de quem a configura: se
   essa conta perder o acesso ao site, a atualização falha.
3. **SQL Server:** mantém a configuração atual (`bdados-14r`, `mdb`), pelo
   gateway de dados local, com a mesma credencial e privacidade
   **Organizacional**.
4. **Gateway e nuvem:** a consulta combina o SharePoint (nuvem) e o SQL Server
   (local) num único passo, então ela é avaliada pelo gateway. Em
   *Gerenciar conexões e gateways*, no cluster do gateway, habilitar
   *Permitir que as fontes de dados de nuvem do usuário sejam atualizadas por
   este cluster de gateway*; nas configurações do conjunto de dados, mapear o
   SQL Server para a conexão do gateway e o SharePoint para a conexão de nuvem
   (OAuth2), conforme o ambiente oferecer.
5. **Teste manual:** *Atualizar agora* e conferir o *Histórico de atualização*
   (status *Concluído*). Conferir no relatório o número de chamados.
6. **Atualização agendada:** configurar o agendamento e, depois da primeira
   execução agendada, conferir de novo o histórico.
7. **Erros comuns:**
   - *contém uma fonte de dados dinâmica* / *não é possível atualizar*: alguém
     trocou o endereço literal de `SharePoint.Files` ou de `Sql.Database` por
     um valor calculado; gere o `.m` de novo pelo gerador;
   - *credenciais inválidas / expiradas* na fonte SharePoint: refazer o login
     OAuth2 (passo 2);
   - *Formula.Firewall*: os passos da consulta foram separados; cole o `.m`
     inteiro de novo;
   - `Feriados: ...`: problema no link ou no conteúdo do arquivo (a mensagem
     indica qual).

### Falhas que interrompem a atualização

Com a mensagem e, quando for o caso, a linha do arquivo:

- credencial do SharePoint ausente ou sem acesso ao site;
- `SharePointFeriadosLink` inválido, de outro site ou sem o caminho do arquivo
  (link curto `/:t:/s/...`);
- arquivo não encontrado na pasta do link, ou mais de um arquivo nela;
- arquivo vazio, sem nenhuma data ou fora de UTF-8;
- título de seção desconhecido;
- data fora do formato, inexistente, repetida ou na seção errada;
- linha só com números e sinais que não seja uma data válida.

O relatório nunca é calculado com zero feriados. Atenção: uma data com texto na
mesma linha **não** interrompe a atualização; ela é ignorada (ver o formato,
acima).

### Onde o calendário pesa neste projeto

A Contagem de cada chamado (24x7 ou Horário TCU) vem do Anexo VII, por Tipo e Prioridade; só os chamados em Horário TCU perdem os dias cadastrados ([`docs/virtual-calculation.md`](../docs/virtual-calculation.md), seções 5 e 6).

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
- As datas com ano (Paixão de Cristo e pontos facultativos) de cada ano novo
  precisam ser cadastradas no `feriados.txt`; os feriados fixos já valem todo
  ano. Não é preciso mudar o SQL nem republicar o relatório.
- Com `FECHAMENTO`, só entram chamados já fechados: um chamado resolvido e
  ainda não fechado aparece no mês em que for fechado. Com `RESOLUCAO`, ele
  aparece no mês da resolução.
