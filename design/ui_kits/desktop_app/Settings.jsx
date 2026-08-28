const NAV = [
  { icon: "audio-lines", label: "Transcrição" },
  { icon: "shield-check", label: "Privacidade" },
  { icon: "keyboard", label: "Ditado" },
  { icon: "folder", label: "Vault" },
  { icon: "plug", label: "MCP" },
];

function Settings() {
  const [sec, setSec] = React.useState("Transcrição");
  const [cloud, setCloud] = React.useState(true);
  return (
    <div style={{ height: "100%", display: "flex", background: "var(--bg-window)" }}>
      <div style={{ width: 210, flex: "0 0 auto", background: "var(--bg-sidebar)", borderRight: "1px solid var(--border-hairline)", padding: "var(--space-3)" }}>
        {NAV.map(n => <SidebarItem key={n.label} icon={n.icon} label={n.label} selected={sec === n.label} onClick={() => setSec(n.label)} />)}
      </div>
      <div style={{ flex: 1, minWidth: 0, padding: "var(--space-7)", overflow: "hidden", background: "var(--bg-surface)" }}>
        <div style={{ maxWidth: 560, display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>
          <h2 style={{ font: "var(--type-title-2)", color: "var(--text-title)" }}>{sec}</h2>

          {sec === "Transcrição" ? (
            <React.Fragment>
              <Card padding="md">
                <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-5)" }}>
                  {[["Ao vivo (pass 1)", ["parakeet-tdt-0.6b-v3","whisper-large-v3-turbo"]],
                    ["Final (pass 2)", ["parakeet-tdt-0.6b-v3 (batch)","whisper-large-v3-turbo","qwen3-asr-1.7b (experimental)"]],
                    ["Diarização", ["fluidaudio-diarizer-v1"]]].map(([label, opts]) => (
                    <div key={label} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-5)" }}>
                      <div>
                        <div style={{ font: "var(--type-ui)" }}>{label}</div>
                        <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", marginTop: 2 }}>roda no Neural Engine</div>
                      </div>
                      <Select mono options={opts} />
                    </div>
                  ))}
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-5)" }}>
                    <div style={{ font: "var(--type-ui)" }}>Idiomas</div>
                    <Select options={["Detectar automaticamente (PT/EN)","Português (BR)","English (US)"]} />
                  </div>
                </div>
              </Card>
              <Card padding="md" inset>
                <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                  <div style={{ font: "var(--type-ui-medium)" }}>Benchmark do seu áudio</div>
                  <div style={{ font: "var(--type-mono-xs)", color: "var(--text-muted)", lineHeight: 1.7 }}>
                    parakeet-tdt-0.6b-v3 &nbsp; WER 2,5% &nbsp; 155× RT<br />
                    whisper-large-v3-turbo &nbsp; WER 3,1% &nbsp; 22× RT<br />
                    qwen3-asr-1.7b &nbsp; WER 2,2% &nbsp; 30× RT
                  </div>
                  <div style={{ marginTop: 8 }}><Button size="sm" variant="secondary" icon="play">Rodar de novo</Button></div>
                </div>
              </Card>
            </React.Fragment>
          ) : sec === "Privacidade" ? (
            <React.Fragment>
              <Card padding="md">
                <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-5)" }}>
                  <Switch checked={cloud} onChange={setCloud} label="Permitir modelos na nuvem (Claude API)" />
                  <div style={{ font: "var(--type-caption)", color: "var(--text-muted)", marginTop: -8 }}>
                    Áudio nunca sai do Mac. Com isto ligado, apenas o texto do transcript pode ser enviado para gerar resumos e respostas — e cada reunião mostra o selo de nuvem.
                  </div>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-5)" }}>
                    <div style={{ font: "var(--type-ui)" }}>Chave da API</div>
                    <div style={{ width: 260 }}><Input defaultValue="sk-ant-•••••••••••••••••" /></div>
                  </div>
                  <Checkbox checked label="Perguntar antes de usar a nuvem em cada reunião" description="Sem isto, o Ouvi usa a nuvem só quando você clicar em Melhorar notas." onChange={() => {}} />
                  <Checkbox checked label="Lembrar de avisar que estou gravando" description="Aviso 5 s antes de começar a gravar." onChange={() => {}} />
                </div>
              </Card>
              <Card padding="md" inset>
                <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)" }}>
                  <PrivacyBadge mode="local" detail="transcrição, diarização e busca" />
                  <PrivacyBadge mode="cloud" detail="resumos e chat, se você ligar" />
                </div>
              </Card>
            </React.Fragment>
          ) : sec === "Ditado" ? (
            <Card padding="md">
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-5)" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <div style={{ font: "var(--type-ui)" }}>Atalho (segurar)</div>
                  <Kbd keys={["fn"]} />
                </div>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <div style={{ font: "var(--type-ui)" }}>Mãos livres (toque duplo)</div>
                  <Switch checked onChange={() => {}} />
                </div>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-5)" }}>
                  <div style={{ font: "var(--type-ui)" }}>Limpeza do texto</div>
                  <Select mono options={["qwen3-4b-instruct-4bit (local)","desligada"]} />
                </div>
                <div>
                  <div style={{ font: "var(--type-ui)", marginBottom: 8 }}>Dicionário pessoal</div>
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                    {["Ouvi","Giro","Aval","Pipa","Superior Grocers","FluidAudio","Parakeet"].map(w => <Tag key={w} onRemove={() => {}}>{w}</Tag>)}
                  </div>
                </div>
                <div>
                  <div style={{ font: "var(--type-ui)", marginBottom: 8 }}>Tom por app</div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 6, font: "var(--type-mono-xs)", color: "var(--text-muted)" }}>
                    <div>com.tinyspeck.slackmacgap &nbsp;→&nbsp; casual</div>
                    <div>com.apple.mail &nbsp;→&nbsp; formal</div>
                    <div>com.todesktop.cursor &nbsp;→&nbsp; literal, sem pontuação extra</div>
                  </div>
                </div>
              </div>
            </Card>
          ) : sec === "Vault" ? (
            <Card padding="md">
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-5)" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-5)" }}>
                  <div>
                    <div style={{ font: "var(--type-ui)" }}>Pasta do vault</div>
                    <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", marginTop: 3 }}>~/Ouvi &nbsp;·&nbsp; 128 notas &nbsp;·&nbsp; 3,4 GB de áudio</div>
                  </div>
                  <Button size="sm" variant="secondary" icon="folder">Trocar</Button>
                </div>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-5)" }}>
                  <div style={{ font: "var(--type-ui)" }}>Guardar áudio</div>
                  <Select options={["Para sempre","90 dias","30 dias","Não guardar"]} />
                </div>
                <Checkbox checked label="Escrever wikilinks de pessoas ([[Eric]])" description="Compatível com Obsidian." onChange={() => {}} />
                <div style={{ display: "flex", gap: "var(--space-3)" }}>
                  <Button size="sm" variant="secondary" icon="download">Exportar tudo</Button>
                  <Button size="sm" variant="ghost">Reindexar do vault</Button>
                </div>
              </div>
            </Card>
          ) : (
            <Card padding="md">
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <div>
                    <div style={{ font: "var(--type-ui-medium)" }}>Servidor MCP local</div>
                    <div style={{ font: "var(--type-caption)", color: "var(--text-muted)", marginTop: 2 }}>Deixa o Claude Desktop e o Claude Code consultarem seu histórico, somente leitura.</div>
                  </div>
                  <Switch checked onChange={() => {}} />
                </div>
                <Card inset padding="sm">
                  <div style={{ font: "var(--type-mono-xs)", color: "var(--text-muted)", lineHeight: 1.8 }}>
                    search_meetings &nbsp;·&nbsp; get_meeting &nbsp;·&nbsp; get_transcript<br />
                    list_people &nbsp;·&nbsp; query_person
                  </div>
                </Card>
                <div style={{ display: "flex", gap: "var(--space-3)" }}>
                  <Button size="sm" variant="secondary" icon="link">Copiar config</Button>
                  <Button size="sm" variant="ghost" icon="file-text">Ver docs</Button>
                </div>
              </div>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}
