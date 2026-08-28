function Code({ children }) {
  return (
    <pre style={{ margin: 0, background: "var(--bg-inset)", borderRadius: "var(--radius-md)", padding: "var(--space-4)", font: "var(--type-mono)", color: "var(--text-body)", boxShadow: "inset 0 0 0 0.5px var(--border-hairline)", overflow: "auto" }}>
      {children}
    </pre>
  );
}

function Docs() {
  const [page, setPage] = React.useState("Permissões");
  return (
    <div style={{ maxWidth: "var(--site-max)", margin: "0 auto", padding: "var(--space-9) var(--space-7)", display: "grid", gridTemplateColumns: "220px 1fr", gap: "var(--space-9)" }}>
      <div style={{ display: "flex", flexDirection: "column", gap: 2, alignSelf: "start", position: "sticky", top: "var(--space-6)" }}>
        <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", padding: "0 8px 6px" }}>Começar</div>
        {["Instalar","Permissões","Vault e Markdown"].map(l => <SidebarItem key={l} label={l} selected={page === l} onClick={() => setPage(l)} />)}
        <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", padding: "14px 8px 6px" }}>Avançado</div>
        {["Modelos e idiomas","Servidor MCP","Compilar do fonte"].map(l => <SidebarItem key={l} label={l} selected={page === l} onClick={() => setPage(l)} />)}
      </div>

      <div style={{ maxWidth: "var(--reading-measure)", display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>
        <div>
          <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", marginBottom: "var(--space-3)" }}>docs / {page.toLowerCase()}</div>
          <h1 style={{ font: "var(--type-title-1)", letterSpacing: "var(--tracking-title)", color: "var(--text-title)" }}>{page}</h1>
        </div>

        {page === "Permissões" ? (
          <React.Fragment>
            <p style={{ font: "var(--type-reading)", color: "var(--text-body)" }}>
              O macOS pede quatro permissões, uma por vez. O Ouvi verifica cada concessão de verdade — o
              sistema às vezes nega em silêncio, então o app tenta ler um buffer antes de dizer que está tudo certo.
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
              {[
                ["Microfone","capta sua voz na reunião e no ditado"],
                ["Gravação de áudio do sistema","capta a outra ponta da call, sem bot e sem Gravação de Tela"],
                ["Acessibilidade","cola o texto ditado no app em foco"],
                ["Calendários","sugere gravar quando a reunião começa"],
              ].map(([n, d]) => (
                <Card key={n} padding="sm">
                  <div style={{ display: "flex", justifyContent: "space-between", gap: "var(--space-4)", alignItems: "center" }}>
                    <div>
                      <div style={{ font: "var(--type-ui-medium)" }}>{n}</div>
                      <div style={{ font: "var(--type-caption)", color: "var(--text-muted)" }}>{d}</div>
                    </div>
                    <Badge tone="neutral">obrigatória</Badge>
                  </div>
                </Card>
              ))}
            </div>
            <p style={{ font: "var(--type-reading)", color: "var(--text-body)" }}>
              Se você negou por engano, o app abre o painel certo dos Ajustes do Sistema:
            </p>
            <Code>{"Ajustes do Sistema → Privacidade e Segurança → Microfone → Ouvi"}</Code>
          </React.Fragment>
        ) : page === "Servidor MCP" ? (
          <React.Fragment>
            <p style={{ font: "var(--type-reading)", color: "var(--text-body)" }}>
              O Ouvi expõe seu histórico por um servidor MCP local, via stdio, somente leitura. Assim o
              Claude Desktop e o Claude Code consultam suas reuniões sem que nada saia do disco.
            </p>
            <Code>{'{\n  "mcpServers": {\n    "ouvi": {\n      "command": "/Applications/Ouvi.app/Contents/MacOS/ouvi-mcp",\n      "args": ["--vault", "~/Ouvi"]\n    }\n  }\n}'}</Code>
            <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
              {[
                ["search_meetings","busca híbrida por texto, pessoa, empresa ou data"],
                ["get_meeting","nota, resumo e metadados de uma reunião"],
                ["get_transcript","transcript com falantes e timestamps"],
                ["list_people","pessoas conhecidas e contagem de reuniões"],
                ["query_person","tudo que você discutiu com alguém"],
              ].map(([n, d]) => (
                <div key={n} style={{ display: "flex", gap: "var(--space-4)", alignItems: "baseline" }}>
                  <span style={{ font: "var(--type-mono)", color: "var(--accent-soft-text)", minWidth: 160 }}>{n}</span>
                  <span style={{ font: "var(--type-body)", color: "var(--text-muted)" }}>{d}</span>
                </div>
              ))}
            </div>
          </React.Fragment>
        ) : page === "Vault e Markdown" ? (
          <React.Fragment>
            <p style={{ font: "var(--type-reading)", color: "var(--text-body)" }}>
              A fonte da verdade é a sua pasta. O índice SQLite é derivado e pode ser reconstruído a
              qualquer momento com <span style={{ font: "var(--type-mono)" }}>ouvi reindex</span>.
            </p>
            <Code>{"~/Ouvi/\n  2026/08/2026-08-27-superior-grocers.md\n  pessoas/eric.md\n  empresas/superior-grocers.md\n  audio/2026-08-27-superior-grocers.m4a"}</Code>
            <Code>{"---\ntitulo: Discovery — Superior Grocers\ndata: 2026-08-27T14:00\nduracao: 41min\nparticipantes: [[Eric]], [[Marina]]\nempresa: [[Superior Grocers]]\nprojeto: Pipa\nidioma: pt-BR\nnuvem: false\n---"}</Code>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <p style={{ font: "var(--type-reading)", color: "var(--text-body)" }}>
              Esta página do kit é uma demonstração de layout. O conteúdo real de <b style={{ fontWeight: 500 }}>{page}</b> entra aqui,
              com a mesma medida de leitura de 68 caracteres, blocos de código em Space Mono e cards para listas de requisitos.
            </p>
            <Code>{"git clone https://github.com/<user>/ouvi\ncd ouvi\n./bundle.sh"}</Code>
            <Placeholder label={"captura de tela — " + page.toLowerCase()} height={220} />
          </React.Fragment>
        )}

        <div style={{ borderTop: "1px solid var(--border-hairline)", paddingTop: "var(--space-5)", display: "flex", gap: "var(--space-4)", alignItems: "center" }}>
          <PrivacyBadge mode="local" detail="documentação de um app que roda no seu Mac" />
          <a href="#" style={{ font: "var(--type-caption)" }}>Editar esta página no GitHub</a>
        </div>
      </div>
    </div>
  );
}
