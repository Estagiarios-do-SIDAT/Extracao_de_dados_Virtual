# Consultas do Power BI — Virtual

Fonte de dados do painel de FAIA e FARC da Virtual. A regra de cálculo está em
[virtual-calculation.md](virtual-calculation.md).

---

## 1. Arquivos

| Arquivo | Conteúdo |
|---|---|
| `powerbi/consulta_virtual_chamados_tcu_power_bi.sql` | aba `Chamados_TCU`, DCIM e Manutenção juntos |
| `powerbi/consulta_virtual_chamados_24x7_power_bi.sql` | aba `Chamados_24x7`, DCIM e Manutenção juntos |

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
8a6054a46d3059603bd538475893be49777fc44ae56a395be34993df8404dae9
```

Ele recebe só `@DataInicio` e `@DataFim` e entrega a
tabela `#Virt_Saida`, com as duas planilhas e os dois regimes. Os arquivos
diferem apenas em:

| | Referência | Power BI |
|---|---|---|
| Período | `@DataInicio` / `@DataFim` digitados | calculado a partir de hoje (seção 4) |
| Planilha | `@Planilha` escolhe DCIM ou Manutenção | as duas, com a coluna `Planilha` |
| Saída | dois resultados (TCU e 24x7) | um arquivo por aba |

Qualquer mudança de regra é feita no bloco da referência e copiada para os dois
arquivos do Power BI. Depois da cópia, os três blocos devem continuar idênticos.

## 3. Como usar no Power BI

1. Obter dados → **SQL Server**.
2. Servidor do SDM, banco `mdb`, modo **Importação**.
3. Em *Opções avançadas → Instrução SQL*, colar o arquivo **inteiro**.
4. Deixar *Incluir colunas de relação* desmarcado.
5. Repetir para o outro arquivo. São duas consultas no modelo, uma por aba.

## 4. Período

No topo de cada arquivo:

```sql
DECLARE @CoberturaMeses int = 12;
```

A janela vai do **dia 1 do mês (corrente − `@CoberturaMeses`)** até o fim do dia
de hoje, pela **data de abertura** do chamado. Com `12`, ela traz os doze meses
fechados anteriores, inteiros, e o mês corrente até hoje. Assim o painel compara
os meses entre si e sempre contém o último mês fechado. Para outra cobertura,
troque só esse número (em *Etapas aplicadas → Fonte*). Nenhuma regra depende
dele.

Exemplo: atualizado em 15/10/2026, com `12`, traz chamados abertos de
01/10/2025 até 15/10/2026.

Volume e tempo de referência (janela 01/10/2025–01/10/2026): 287 chamados no
total (275 em `Chamados_TCU`, 12 em `Chamados_24x7`), entre 16 e 36 por
mês; 30 a 40 segundos por consulta.

Como o mês é o da **abertura**, um chamado aberto no período e resolvido depois
aparece no mês em que foi aberto, com a resolução real.

## 5. Saída

As 23 colunas das abas, na ordem da planilha, mais `Planilha` no final:

| # | Coluna | Unidade |
|---|---|---|
| 1 | ID Chamado | — |
| 2 | Descrição do Chamado | — |
| 3 | Tipo (Incidente/Solicitação) | — |
| 4 | Prioridade | 1 a 5 |
| 5 | Regime | `TCU` / `24x7` |
| 6 | Data/Hora Abertura | data e hora (Brasil) |
| 7 | Data/Hora Início Atendimento | data e hora (Brasil) |
| 8 | Data/Hora Resolução | data e hora (Brasil) |
| 9 | Tini (h) | horas decimais |
| 10 | Tsol (h) | horas decimais |
| 11 | Horas Comerciais Resposta (h) | horas decimais |
| 12 | Horas Não Comerciais Resposta (h) | horas decimais |
| 13 | Horas Comerciais Resolução (h) | horas decimais |
| 14 | Horas Não Comerciais Resolução (h) | horas decimais |
| 15 | Meta Resposta (h) | horas decimais |
| 16 | Meta Resolução (h) | horas decimais |
| 17 | Excesso Resposta (h) | horas decimais |
| 18 | Excesso Resolução (h) | horas decimais |
| 19 | chave | `Tipo\|Prioridade\|Regime` |
| 20 | Fator FARC | decimal |
| 21 | Indice FARC | pontos percentuais |
| 22 | Fator FAIA | decimal |
| 23 | Indice FAIA | pontos percentuais |
| 24 | Planilha | `DCIM` / `Manutenção` |

Uma linha por chamado. Nas planilhas os tempos aparecem como `[h]:mm:ss`; aqui
saem como número de horas (1,5 = 1h30).

Para chegar aos totais da aba Cálculos de uma planilha em um mês, filtre
`Planilha` e o mês de `Data/Hora Abertura` e some `Indice FAIA` e `Indice FARC`
nas duas consultas. O Financeiro aplica `Total / 100` sobre o valor mensal da
planilha: R$ 16.000,00 no DCIM e R$ 22.000,00 na Manutenção.

## 6. Conferência

Com o mesmo período, a soma das duas consultas do Power BI filtrada por
`Planilha` tem as mesmas linhas e os mesmos valores dos dois resultados da
referência rodada com `@Planilha` correspondente. Conferido em maio/2026 (01/05 a
30/05, 23 chamados) e na janela de 12 meses de 01/10/2025 a 01/10/2026 (287
chamados): nenhuma diferença nas 23 colunas.

Para conferir, troque no arquivo do Power BI as duas linhas que calculam
`@DataInicio` e `@DataFim` por datas fixas iguais às da referência.

## 7. Cuidados

- A consulta cria só tabelas temporárias (`#Virt_*`). Não grava nada no banco.
- O calendário embutido vai até 31/12/2026 e precisa ser atualizado a cada ano
  no bloco `[2]` do motor, na referência, e depois copiado para os dois
  arquivos do Power BI (ver
  [virtual-calculation.md, seção 13](virtual-calculation.md#13-cuidados-e-limitações)).
  Com a janela de 12 meses, a partir de janeiro de 2027 parte da janela fica
  fora do calendário até essa atualização.
- Chamados do mês corrente ainda sem início ou sem resolução saem com as
  colunas correspondentes vazias. Os índices só ficam definitivos depois da
  resolução.
