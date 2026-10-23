# Split Video

Script em PowerShell para dividir vídeos grandes em partes menores usando `ffmpeg`, sem reencodar o arquivo original. As partes são geradas com o mesmo codec e qualidade do vídeo de entrada.

## Funcionalidades

- Divide vídeos por tamanho alvo em MB.
- Usa `ffmpeg` com `-c copy`, preservando a qualidade e tornando o processo rápido.
- Cortes alinhados aos keyframes do vídeo.
- Timestamps reiniciados em cada parte para melhor compatibilidade.
- Validação de arquivo de entrada, `ffmpeg` e `ffprobe`.
- Opções para pasta de saída, prefixo dos arquivos e sobrescrita.
- Resumo final com duração e tamanho de cada parte.
- Aviso quando alguma parte ultrapassa o tamanho alvo.

## Requisitos

- Windows com PowerShell 5.1 ou superior, ou PowerShell 7+.
- `ffmpeg` e `ffprobe` instalados e disponíveis no `PATH`.

Para verificar:

```powershell
ffmpeg -version
ffprobe -version
```

## Arquivos

| Arquivo | Descrição |
|---|---|
| `Split-Video.ps1` | Script principal. |
| `Run.bat` | Atalho para executar o script com duplo clique ou arrastar-e-soltar. |

## Uso rápido

Arraste um arquivo de vídeo para cima do `Run.bat`. O limite padrão será de **195 MB**.

Ou execute pelo terminal:

```bat
Run.bat "C:\videos\aula.mp4"
Run.bat "C:\videos\aula.mp4" 100
```

O primeiro argumento é o vídeo e o segundo é o tamanho máximo em MB.

## Uso direto no PowerShell

```powershell
.\Split-Video.ps1 -InputFile "C:\videos\aula.mp4"
```

Definindo o tamanho alvo:

```powershell
.\Split-Video.ps1 -InputFile "C:\videos\aula.mp4" -MaxSizeMB 100
```

Salvando as partes em outra pasta:

```powershell
.\Split-Video.ps1 -InputFile "C:\videos\aula.mp4" -MaxSizeMB 100 -OutputDir ".\partes"
```

Definindo um prefixo para os arquivos:

```powershell
.\Split-Video.ps1 -InputFile "C:\videos\aula.mp4" -Prefix "aula-modulo1"
```

Substituindo partes já existentes:

```powershell
.\Split-Video.ps1 -InputFile "C:\videos\aula.mp4" -Force
```

## Parâmetros

| Parâmetro | Obrigatório | Padrão | Descrição |
|---|---|---|---|
| `-InputFile` | Sim | — | Caminho do vídeo de entrada. |
| `-MaxSizeMB` | Não | `200` | Tamanho alvo de cada parte, em MB. |
| `-OutputDir` | Não | Pasta do vídeo | Pasta onde as partes serão salvas. |
| `-Prefix` | Não | Nome do vídeo | Prefixo dos arquivos gerados. |
| `-Force` | Não | Desativado | Remove/substitui partes existentes com o mesmo nome. |

## Arquivos gerados

Para um vídeo chamado `aula.mp4`, o resultado será:

```text
aula-part001.mp4
aula-part002.mp4
aula-part003.mp4
...
```

Por padrão, as partes são salvas na mesma pasta do vídeo original.

## Como funciona

1. O script usa `ffprobe` para obter a duração e a taxa de bits do vídeo.
2. Calcula uma duração alvo por parte com base em `MaxSizeMB` e aplica uma margem de segurança de 25%.
3. Executa o muxer `segment` do `ffmpeg` com `-c copy` e `-reset_timestamps 1`.
4. Ao final, exibe uma tabela com número da parte, caminho, duração e tamanho.

## Limitações

- O `MaxSizeMB` é um **alvo aproximado**, não um limite rígido.
- Os cortes acontecem em keyframes. Vídeos com keyframes muito distantes podem gerar partes maiores que o alvo.
- Se uma parte exceder o limite, o script emite um aviso. Nesse caso, reduza `-MaxSizeMB` ou reencode o vídeo com keyframes mais frequentes.
- Como o vídeo não é reencodado, não é possível cortar em qualquer ponto exato.
- Streams incomuns (legendas, dados extras) podem não ser compatíveis com todos os contêineres.

## Solução de problemas

**`ffmpeg e ffprobe devem estar instalados e disponiveis no PATH`**

Instale o ffmpeg e adicione a pasta `bin` ao `PATH`. Feche e abra o terminal novamente.

**O PowerShell bloqueia a execução do script**

Use uma das opções abaixo, sem alterar a política global:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Ou execute pelo `Run.bat`, que já utiliza `-ExecutionPolicy Bypass`.

**Já existem partes com esse nome**

Use `-Force` para removê-las e gerar novamente.

**O vídeo não é dividido corretamente**

Confira se o arquivo de entrada está íntegro e se o contêiner é compatível com o muxer `segment`. Teste primeiro com uma cópia curta do vídeo.

## Segurança

O projeto não utiliza chaves de API nem envia arquivos para serviços externos. Todo o processamento é local.
