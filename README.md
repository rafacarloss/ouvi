# Ouvi

**Your meetings, your voice, your files.** Ouvi é um app de notas de reunião e ditado por voz para macOS — como o Granola e o Wispr Flow — só que **100% local, open source e com os dados no seu computador**.

> "Ouvi" = *"I heard"* em português.

## Por quê

Os apps de notas de reunião mandam seu áudio para a nuvem, treinam modelos com suas conversas por padrão e trancam suas notas num banco criptografado. O Ouvi faz o caminho oposto:

- **Sem bot na call.** Captura o microfone + o áudio do sistema direto do macOS (Core Audio process taps). Funciona com Zoom, Meet, Teams, Slack, FaceTime — qualquer coisa que você ouve.
- **Transcrição impecável, on-device.** Parakeet-TDT v3 (NVIDIA) rodando no Neural Engine via [FluidAudio](https://github.com/FluidInference/FluidAudio) — 25 idiomas incluindo português e inglês, timestamps por palavra, ~40x tempo real. O áudio **nunca** sai do seu Mac.
- **Diarização local com nomes.** Identifica quem falou, você nomeia uma vez ("essa voz é a Sayuri"), e as próximas reuniões já chegam nomeadas. O perfil de voz fica só no seu Mac — e é grátis, sem paywall.
- **Files over app.** Notas e transcrições viram arquivos Markdown com frontmatter numa pasta sua — compatível com Obsidian, versionável com git. O SQLite é só um índice reconstruível.
- **Ditado em qualquer app.** Segure **Fn** (ou ⌥Espaço), fale, solte — o texto aparece formatado onde estiver o cursor, com limpeza de "ãã", pontuação e dicionário pessoal.
- **Knowledge base com MCP.** Busca híbrida (full-text + semântica) sobre todo o histórico, chat com citações, páginas por pessoa — e um **servidor MCP local** que expõe suas reuniões ao Claude, Cursor ou qualquer cliente MCP.
- **Nuvem só se você quiser.** Resumos e chat podem usar o Claude com a *sua* chave de API (só texto, nunca áudio, com selo visível por reunião) — ou um LLM local via Ollama/LM Studio, ou nada.

## Instalação (por enquanto: build local)

Requisitos: macOS 14.4+, Apple Silicon, Swift 6 (Command Line Tools bastam).

```bash
git clone https://github.com/rafacarloss/ouvi.git
cd ouvi
./scripts/bundle.sh release
open dist/Ouvi.app
```

Na primeira gravação o macOS pede as permissões (Microfone, Gravação de Áudio do Sistema) e o app baixa os modelos de ASR (~1 GB, uma vez). Para o ditado inserir texto, autorize Acessibilidade em Ajustes do Sistema.

### Ferramentas de linha de comando

```bash
.build/release/ouvi-cli transcribe reuniao.m4a --lang pt   # transcreve qualquer arquivo de áudio
.build/release/ouvi-cli diarize reuniao.m4a                # quem falou quando
.build/release/ouvi-mcp --doctor                           # self-check da instalação
```

### MCP (Claude Desktop / Claude Code)

```json
{
  "mcpServers": {
    "ouvi": { "command": "/Applications/Ouvi.app/Contents/Helpers/ouvi-mcp" }
  }
}
```

Ferramentas expostas (somente leitura): `list_recent_meetings`, `search_meetings`, `get_transcript`, `get_meeting_summary`, `list_people`.

## Arquitetura

```
mic ─────────┐                       ┌─ draft ao vivo (streaming)
             ├─ 2 canais separados ──┤
system audio ┘   (VPIO AEC, taps)    └─ passe final: Parakeet v3 (ANE)
                                          ├─ diarização offline + voice enrollment
                                          ├─ SQLite (GRDB + FTS5 + sqlite-vec)
                                          └─ vault Markdown (fonte da verdade)
```

- **Canais separados para sempre**: mic = "eu", sistema = "eles" — atribuição de falante de graça, diarização só no canal remoto.
- **Swift/SwiftUI nativo**, sem Electron. GRDB 7, FluidAudio (CoreML/ANE), sqlite-vec.
- Sem conta, sem telemetria, sem backend.

## Status

v0.1 — em desenvolvimento ativo. Funciona: gravação dois-canais, transcrição PT/EN com timestamps, diarização com re-identificação de voz, resumos/enhance/chat (Claude ou LLM local), vault Markdown, ditado com hotkey global, servidor MCP. Roadmap: onboarding guiado, templates, import de arquivos, streaming ao vivo na UI, releases assinados via Sparkle, app iOS companion.

## Licença

[GPL-3.0](LICENSE). Modelos: Parakeet-TDT-0.6b-v3 e pipeline de diarização da NVIDIA/FluidInference (CC-BY-4.0 — atribuição no About).
