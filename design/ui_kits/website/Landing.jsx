function Section({ children, style }) {
  return <section style={{ maxWidth: "var(--site-max)", margin: "0 auto", padding: "var(--space-12) var(--space-7)", ...style }}>{children}</section>;
}

function Kicker({ children }) {
  return <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", marginBottom: "var(--space-4)" }}>{children}</div>;
}

function Landing() {
  return (
    <div>
      <Section style={{ paddingTop: "var(--space-11)", paddingBottom: "var(--space-9)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)", marginBottom: "var(--space-6)" }}>
          <Badge tone="local">100% local</Badge>
          <Badge tone="neutral">gpl-3.0</Badge>
          <Badge tone="neutral">macos 14.4+</Badge>
        </div>
        <h1 style={{ font: "var(--type-hero)", letterSpacing: "var(--tracking-display)", color: "var(--text-title)", maxWidth: "18ch" }}>
          Suas reuniões, sua voz, seus arquivos.
        </h1>
        <p style={{ font: "var(--weight-light) var(--text-xl)/1.5 var(--font-sans)", color: "var(--text-muted)", maxWidth: "52ch", marginTop: "var(--space-6)" }}>
          O Ouvi grava suas reuniões sem bot, transcreve no seu Mac e escreve tudo em Markdown numa pasta
          que é sua. Nenhum áudio sai do dispositivo.
        </p>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", marginTop: "var(--space-7)", flexWrap: "wrap" }}>
          <Button variant="primary" size="lg" icon="download">Baixar para macOS</Button>
          <Button variant="secondary" size="lg" icon="github">Ver no GitHub</Button>
          <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>v0.1 · apple silicon · 48 MB</span>
        </div>
        <div style={{ marginTop: "var(--space-9)" }}>
          <Placeholder label="captura de tela — janela principal gravando (1180×700)" height={420} />
        </div>
      </Section>

      <Section style={{ paddingTop: "var(--space-9)" }}>
        <Kicker>como funciona</Kicker>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "var(--space-5)" }}>
          {[
            { i: "mic", t: "Grava sem bot", d: "Captura seu microfone e o áudio do sistema em dois canais separados. Nada entra na sua call." },
            { i: "audio-lines", t: "Transcreve no Neural Engine", d: "Rascunho ao vivo e um passe final de alta acurácia, com timestamps por palavra, em PT e EN." },
            { i: "folder", t: "Escreve na sua pasta", d: "Markdown com frontmatter, wikilinks de pessoas e o áudio ao lado. Abre no Obsidian." },
          ].map(c => (
            <Card key={c.t} padding="lg">
              <span style={{ color: "var(--accent)" }}><Icon name={c.i} size={20} /></span>
              <div style={{ font: "var(--type-title-3)", color: "var(--text-title)", marginTop: "var(--space-4)" }}>{c.t}</div>
              <p style={{ font: "var(--type-body)", color: "var(--text-muted)", marginTop: "var(--space-3)" }}>{c.d}</p>
            </Card>
          ))}
        </div>
      </Section>

      <Section>
        <div style={{ display: "grid", gridTemplateColumns: "1.1fr 1fr", gap: "var(--space-9)", alignItems: "center" }}>
          <div>
            <Kicker>transcrição</Kicker>
            <h2 style={{ font: "var(--type-display)", letterSpacing: "var(--tracking-display)", color: "var(--text-title)", maxWidth: "22ch" }}>Falantes com nome, não “Falante 2”.</h2>
            <p style={{ font: "var(--type-reading)", color: "var(--text-muted)", maxWidth: "46ch", marginTop: "var(--space-5)" }}>
              A diarização roda local e você nomeia cada voz uma vez. Nas próximas reuniões ela já chega
              identificada — e o registro de voz nunca sai do seu Mac.
            </p>
            <div style={{ display: "flex", gap: "var(--space-5)", marginTop: "var(--space-6)", font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>
              <span>WER 2,5%</span><span>155× tempo real</span><span>DER 10,6%</span>
            </div>
          </div>
          <Card padding="md">
            <TranscriptLine speaker="Você" slot={0} time="00:14:22" text="Então roda local. Piloto de 60 dias, dois times." onSeek={() => {}} />
            <TranscriptLine speaker="Eric" slot={1} time="00:14:41" text="Consigo aprovar essa semana se receber o escopo." onSeek={() => {}} />
            <TranscriptLine speaker="Falante 3" slot={2} unnamed draft time="00:14:58" text="libero o staging na quinta e-- aliás, na sexta" onSeek={() => {}} />
          </Card>
        </div>
      </Section>

      <Section>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1.1fr", gap: "var(--space-9)", alignItems: "center" }}>
          <Card padding="lg" inset>
            <div style={{ display: "flex", justifyContent: "center", padding: "var(--space-6) 0" }}>
              <DictationPill state="listening" target="Slack · casual" />
            </div>
            <div style={{ display: "flex", justifyContent: "center", gap: "var(--space-4)", font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>
              <span>segure fn</span><span>&lt; 1 s até colar</span><span>limpeza local</span>
            </div>
          </Card>
          <div>
            <Kicker>ditado</Kicker>
            <h2 style={{ font: "var(--type-display)", letterSpacing: "var(--tracking-display)", color: "var(--text-title)", maxWidth: "22ch" }}>Fale em qualquer app.</h2>
            <p style={{ font: "var(--type-reading)", color: "var(--text-muted)", maxWidth: "46ch", marginTop: "var(--space-5)" }}>
              Segure a tecla, fale, solte. O texto sai pontuado, sem “ãã”, no tom do app em que você está —
              e um modelo local faz a limpeza. Sem limite de palavras, sem assinatura.
            </p>
          </div>
        </div>
      </Section>

      <Section>
        <Kicker>base de conhecimento</Kicker>
        <h2 style={{ font: "var(--type-display)", letterSpacing: "var(--tracking-display)", color: "var(--text-title)", maxWidth: "26ch" }}>Tudo que você já discutiu, pesquisável.</h2>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "var(--space-4)", marginTop: "var(--space-7)" }}>
          {[
            { i: "search", t: "Busca híbrida", d: "palavra-chave e sentido, no mesmo índice local" },
            { i: "user", t: "Páginas de pessoas", d: "histórico, pendências e tom, sem custo extra" },
            { i: "message-square", t: "Chat com citação", d: "toda resposta aponta o minuto exato" },
            { i: "plug", t: "Servidor MCP", d: "o Claude lê seu histórico, somente leitura" },
          ].map(c => (
            <Card key={c.t} padding="md">
              <span style={{ color: "var(--accent)" }}><Icon name={c.i} size={18} /></span>
              <div style={{ font: "var(--type-ui-medium)", marginTop: "var(--space-3)" }}>{c.t}</div>
              <div style={{ font: "var(--type-caption)", color: "var(--text-muted)", marginTop: 4 }}>{c.d}</div>
            </Card>
          ))}
        </div>
        <div style={{ marginTop: "var(--space-7)" }}>
          <Placeholder label="captura de tela — busca e chat com citações (1120×520)" height={340} />
        </div>
      </Section>

      <Section>
        <Card padding="lg">
          <div style={{ display: "flex", gap: "var(--space-9)", flexWrap: "wrap", alignItems: "flex-start" }}>
            <div style={{ flex: 1, minWidth: 280 }}>
              <Kicker>privacidade, na prática</Kicker>
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
                {[
                  "Áudio, transcrição, diarização e busca rodam no seu Mac.",
                  "Sem conta, sem login, sem telemetria — nada para desligar.",
                  "Resumos por IA na nuvem são opcionais, com sua chave, e sempre marcados.",
                  "O código é GPL-3.0: qualquer pessoa pode auditar o que sai do dispositivo.",
                ].map(t => (
                  <div key={t} style={{ display: "flex", gap: "var(--space-3)", font: "var(--type-body)" }}>
                    <span style={{ color: "var(--accent)", marginTop: 2 }}><Icon name="check" size={15} /></span>
                    <span>{t}</span>
                  </div>
                ))}
              </div>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)", minWidth: 240 }}>
              <PrivacyBadge mode="local" detail="captura e transcrição" />
              <PrivacyBadge mode="cloud" detail="resumos, se você ligar" />
              <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", lineHeight: 1.8, marginTop: "var(--space-3)" }}>
                ~/Ouvi/2026/08/2026-08-27-superior-grocers.md<br />
                ~/Ouvi/audio/2026-08-27-superior-grocers.m4a
              </div>
            </div>
          </div>
        </Card>
      </Section>

      <Section style={{ paddingBottom: "var(--space-11)" }}>
        <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: "var(--space-7)", flexWrap: "wrap" }}>
          <div>
            <h2 style={{ font: "var(--type-display)", letterSpacing: "var(--tracking-display)", color: "var(--text-title)" }}>Baixe e rode hoje.</h2>
            <p style={{ font: "var(--type-reading)", color: "var(--text-muted)", maxWidth: "46ch", marginTop: "var(--space-4)" }}>
              Binário assinado e notarizado, ou compile do fonte. As duas rotas dão o mesmo app.
            </p>
          </div>
          <div style={{ display: "flex", gap: "var(--space-3)" }}>
            <Button variant="primary" size="lg" icon="download">Baixar .dmg</Button>
            <Button variant="secondary" size="lg" icon="command">brew install ouvi</Button>
          </div>
        </div>
      </Section>
    </div>
  );
}
