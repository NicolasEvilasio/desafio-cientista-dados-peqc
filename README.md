# Registro Municipal Integrado — educação

Pipeline dbt no BigQuery para os dados educacionais anonimizados do Registro Municipal Integrado (RMI). Os arquivos Parquet ficam no Google Cloud Storage e entram no warehouse como tabelas externas. Os models seguem as camadas staging, intermediate e marts.

Os datasets abaixo são criados no projeto GCP definido em `GCP_PROJECT`, no arquivo `.env`.

| Camada | Dataset |
|---|---|
| Tabelas externas (Parquet) | `brutos_registro_municipal_integrado_staging` |
| Staging | `brutos_registro_municipal_integrado` |
| Intermediate e marts | `educacao_registro_municipal_integrado` |

## Contexto

O RMI é o data warehouse da Prefeitura do Rio de Janeiro. Ele consolida dados de saúde, educação, assistência social e outros sistemas municipais. Este repositório usa um recorte educacional anonimizado dessa base.

## Dados

Os registros são da rede municipal de ensino, anonimizados e aleatorizados. Cada tabela é um objeto Parquet no bucket `case_vagas`, prefixo `rmi`. O nome do objeto não tem sufixo `.parquet`.

| Objeto GCS | Descrição | Granularidade |
|---|---|---|
| `gs://case_vagas/rmi/aluno` | Cadastro de alunos (IDs anonimizados, faixa etária, bairro anonimizado) | 1 linha por aluno |
| `gs://case_vagas/rmi/escola` | Cadastro de unidades escolares (IDs anonimizados, tipo, região) | 1 linha por escola |
| `gs://case_vagas/rmi/turma` | Turmas (série, turno, ano letivo) | 1 linha por turma |
| `gs://case_vagas/rmi/frequencia` | Frequência escolar | 1 linha por aluno/dia |
| `gs://case_vagas/rmi/avaliacao` | Notas por bimestre | 1 linha por aluno/disciplina/bimestre |

Console do bucket: https://console.cloud.google.com/storage/browser/case_vagas/rmi

Tabela pública auxiliar no BigQuery: `datario.dados_mestres.bairro` (cadastro de bairros do Rio de Janeiro).

Os identificadores pessoais (nomes, CPFs, endereços) foram removidos e trocados por IDs sintéticos. Os valores numéricos foram aleatorizados, com as distribuições e as chaves de relacionamento preservadas entre as tabelas (`id_aluno`, `id_escola`, `id_turma`). Não dá para reidentificar um registro nem cruzar com fonte externa. Estes dados não descrevem a rede real.

As sources estão em `dbt/models/raw_staging/sources.yml`.

## Pré-requisitos

- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Um projeto GCP em que a sua conta possa criar datasets e jobs do BigQuery

O uv instala o Python 3.13 definido em `.python-version`.

## Como executar

Na raiz do repositório, crie o `.env` a partir do exemplo:

```bash
cp .env.example .env
```

Abra o `.env` e troque o valor pelo id do seu projeto GCP.

```
GCP_PROJECT=seu-projeto-gcp
```

Rode o setup:

```bash
./scripts/dev/setup.sh
```

O script lê esse `.env`, cria uma configuração do gcloud com o nome do projeto sem trocar a configuração padrão da máquina, abre o navegador para `gcloud auth login` e `gcloud auth application-default login`, roda `uv sync`, instala o pre-commit e baixa os pacotes do dbt (`dbt deps`).

O `gcloud auth application-default login` grava a credencial em `~/.config/gcloud/application_default_credentials.json`. O target `dev` em `dbt/profiles.yml` usa `method: oauth` e lê esse arquivo. O `uv run` lê o `GCP_PROJECT` do `.env` na hora do comando.

Construa os models:

```bash
uv run dbt build --project-dir dbt --profiles-dir dbt
```

O `dbt build` também cria as tabelas externas, se ainda não existirem, pelo hook `on-run-start` do `dbt/dbt_project.yml`.

## CI

O workflow `.github/workflows/dbt.yml` roda no GitHub deste repositório, no push para `master` e em pull requests.

Para esse workflow autenticar no GCP, a identidade federada precisa estar configurada. Os passos estão em [`scripts/ci/README.md`](scripts/ci/README.md).

Para critérios de avaliação, executar esse script é dispensável, já que os actions executados podem ser visualizados no GitHub.
