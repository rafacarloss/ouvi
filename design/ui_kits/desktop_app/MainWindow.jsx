const SESSIONS = [
  { t: "Discovery — Superior Grocers", w: "hoje 14:00", d: "41 min", s: "3 falantes", live: true },
  { t: "1:1 — Eric", w: "ontem 09:30", d: "24 min", s: "2 falantes", cloud: true },
  { t: "Pipa — pipeline review", w: "ter 16:00", d: "52 min", s: "5 falantes" },
  { t: "Aval — kickoff jurídico", w: "seg 11:00", d: "38 min", s: "4 falantes" },
  { t: "Giro — retro do sprint", w: "23 ago", d: "29 min", s: "6 falantes" },
];

const LINES = [
  { sp: "Você", slot: 0, t: "00:13:58", x: "Antes de entrar em preço, deixa eu confirmar: o dado precisa ficar na infra de vocês, certo?" },
  { sp: "Eric", slot: 1, t: "00:14:22", x: "Exatamente. Qualquer coisa que suba pra fora passa por comitê, e isso leva uns dois meses." },
  { sp: "Você", slot: 0, t: "00:14:41", x: "Então roda local. Piloto de 60 dias, dois times, e a gente mede adoção por semana." },
  { sp: "Falante 3", slot: 2, unnamed: true, t: "00:14:58", x: "eu consigo liberar o ambiente de staging na quinta e-- aliás, na sexta, porque quinta tem feriado", draft: true },
];

function MainWindow({ theme }) {
  const [sel, setSel] = React.useState(0);
  const [tab, setTab] = React.useState("Notas");
  const [enhanced, setEnhanced] = React.useState(false);
  const [rail, setRail] = React.useState(true);

  return (
    <div style={{ display: "flex", height: "100%", minHeight: 0, background: "var(--bg-window)" }}>
      {/* sidebar */}
      <div style={{ width: "var(--sidebar-width)", flex: "0 0 auto", background: "var(--bg-sidebar)", borderRight: "1px solid var(--border-hairline)", padding: "var(--space-3)", display: "flex", flexDirection: "column", gap: 2 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "2px 8px 10px" }}>
          <span style={{ fontFamily: "var(--font-sans)", fontWeight: 900, fontSize: 17, letterSpacing: "-0.03em", color: "var(--text-title)" }}>ouvi</span>
          <span style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--live)", marginTop: 5 }} />
        </div>
        <SidebarItem icon="calendar" label="Hoje" count={3} selected />
        <SidebarItem icon="audio-lines" label="Todas as reuniões" count={128} />
        <SidebarItem icon="message-square" label="Conversar com o histórico" />
        <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", padding: "14px 8px 4px" }}>Pessoas</div>
        <SidebarItem icon="user" label="Eric" count={9} indent={1} />
        <SidebarItem icon="user" label="Marina" count={6} indent={1} />
        <SidebarItem icon="building-2" label="Superior Grocers" count={4} indent={1} />
        <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", padding: "14px 8px 4px" }}>Projetos</div>
        <SidebarItem icon="folder" label="Giro" indent={1} />
        <SidebarItem icon="folder" label="Aval" indent={1} />
        <SidebarItem icon="folder" label="Pipa" indent={1} />
        <div style={{ marginTop: "auto", padding: "var(--space-3) var(--space-2)", display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
          <PrivacyBadge mode="local" detail="tudo neste Mac" />
          <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>~/Ouvi · 128 notas · 41 pessoas</div>
        </div>
      </div>

      {/* list */}
      <div style={{ width: 300, flex: "0 0 auto", borderRight: "1px solid var(--border-hairline)", display: "flex", flexDirection: "column", background: "var(--bg-window)" }}>
        <div style={{ padding: "var(--space-3)", borderBottom: "1px solid var(--border-hairline)", display: "flex", gap: "var(--space-3)", alignItems: "center" }}>
          <SearchField placeholder="Buscar em tudo" shortcut={["⌘","K"]} />
        </div>
        <div style={{ padding: "var(--space-2)", overflow: "hidden" }}>
          {SESSIONS.map((s, i) => (
            <SessionRow key={s.t} title={s.t} when={s.w} duration={s.d} speakers={s.s} cloud={s.cloud} live={s.live} selected={i === sel} onClick={() => setSel(i)} />
          ))}
        </div>
      </div>

      {/* content */}
      <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", background: "var(--bg-surface)" }}>
        <Toolbar
          leading={<RecordButton state="recording" elapsed="12:04" size="sm" />}
          trailing={
            <span style={{ display: "flex", gap: 4 }}>
              <IconButton icon="sparkles" title="Melhorar notas" onClick={() => setEnhanced(true)} active={enhanced} />
              <IconButton icon="audio-lines" title="Transcript" active={rail} onClick={() => setRail(!rail)} />
              <IconButton icon="download" title="Exportar" />
            </span>
          }
        >
          <div style={{ display: "flex", flexDirection: "column", minWidth: 0 }}>
            <span style={{ font: "var(--type-ui-medium)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{SESSIONS[sel].t}</span>
            <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>{SESSIONS[sel].w} · discovery call · pt-BR</span>
          </div>
        </Toolbar>

        <div style={{ display: "flex", flex: 1, minHeight: 0 }}>
          <div style={{ flex: 1, minWidth: 0, padding: "var(--space-6) var(--space-7)", overflow: "hidden" }}>
            <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)", marginBottom: "var(--space-5)" }}>
              <SegmentedControl options={["Notas","Transcript","Resumo"]} value={tab} onChange={setTab} style={{ alignSelf: "flex-start" }} />
              <div style={{ display: "flex", gap: "var(--space-3)", alignItems: "center", flexWrap: "wrap" }}>
                <Tag icon="user">Eric</Tag>
                <Tag icon="building-2">Superior Grocers</Tag>
                <Tag icon="folder">Pipa</Tag>
              </div>
            </div>

            {tab === "Notas" ? (
              <div style={{ maxWidth: "var(--reading-measure)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
                <div style={{ font: "var(--type-title-2)", letterSpacing: "var(--tracking-title)", color: "var(--text-title)" }}>Discovery — Superior Grocers</div>
                <ul style={{ margin: 0, paddingLeft: 18, display: "flex", flexDirection: "column", gap: "var(--space-3)", font: "var(--type-reading)", color: "var(--text-body)" }}>
                  <li>dado tem que ficar on-prem — comitê leva 2 meses</li>
                  <li>piloto 60d, 2 times, medir adoção semanal</li>
                  <li>staging liberado sexta</li>
                  {enhanced ? (
                    <React.Fragment>
                      <li style={{ color: "var(--text-muted)" }}>
                        Eric pode aprovar o piloto nesta semana desde que receba o escopo por escrito.
                        <Citation time="14:22" />
                      </li>
                      <li style={{ color: "var(--text-muted)" }}>
                        Restrição dura: qualquer dado que saia da infra passa por comitê (≈2 meses) — o piloto precisa rodar local.
                        <Citation time="13:58" />
                      </li>
                      <li style={{ color: "var(--text-muted)" }}>
                        Próximo passo com dono: você envia o escopo de 60 dias até sexta.
                        <Citation time="14:58" />
                      </li>
                    </React.Fragment>
                  ) : null}
                </ul>
                {enhanced ? (
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", marginTop: "var(--space-3)" }}>
                    <PrivacyBadge mode="cloud" detail="resumo pela Claude API — só o texto do transcript foi enviado" />
                    <Button variant="ghost" size="sm" icon="sparkles" onClick={() => setEnhanced(false)}>Refazer</Button>
                  </div>
                ) : (
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", marginTop: "var(--space-3)", flexWrap: "wrap" }}>
                    <Button variant="primary" icon="sparkles" onClick={() => setEnhanced(true)}>Melhorar notas</Button>
                    <span style={{ font: "var(--type-caption)", color: "var(--text-muted)" }}>suas linhas ficam como estão; as adições da IA entram em cinza, com citação</span>
                  </div>
                )}
              </div>
            ) : tab === "Transcript" ? (
              <div style={{ maxWidth: "var(--reading-measure)" }}>
                {LINES.map(l => (
                  <TranscriptLine key={l.t} speaker={l.sp} slot={l.slot} unnamed={l.unnamed} draft={l.draft} time={l.t} text={l.x} onSeek={() => {}} />
                ))}
              </div>
            ) : (
              <div style={{ maxWidth: "var(--reading-measure)", display: "flex", flexDirection: "column", gap: "var(--space-5)" }}>
                <Card padding="lg">
                  <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", marginBottom: 8 }}>Decisões</div>
                  <div style={{ font: "var(--type-reading)" }}>Piloto roda 100% na infra do cliente.<Citation time="14:41" /></div>
                </Card>
                <Card padding="lg">
                  <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", marginBottom: 8 }}>Action items</div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 8, font: "var(--type-reading)" }}>
                    <div><b style={{ fontWeight: 500 }}>Você</b> — enviar escopo de 60 dias até sexta<Citation time="14:58" /></div>
                    <div><b style={{ fontWeight: 500 }}>Eric</b> — liberar staging e levar ao comitê<Citation time="15:10" /></div>
                  </div>
                </Card>
                <div style={{ display: "flex", gap: "var(--space-3)" }}>
                  <Button variant="secondary" icon="file-text">Rascunho de follow-up</Button>
                  <Button variant="ghost" icon="download">Exportar .md</Button>
                </div>
              </div>
            )}
          </div>

          {rail ? (
            <div style={{ width: "var(--transcript-width)", flex: "0 0 auto", borderLeft: "1px solid var(--border-hairline)", background: "var(--bg-inset)", display: "flex", flexDirection: "column", minHeight: 0 }}>
              <div style={{ padding: "var(--space-4)", display: "flex", alignItems: "center", justifyContent: "space-between", borderBottom: "1px solid var(--border-hairline)" }}>
                <Badge tone="live" dot>ao vivo · 12:04</Badge>
                <Waveform bars={14} live height={18} />
              </div>
              <div style={{ padding: "var(--space-2)", overflow: "hidden", flex: 1 }}>
                {LINES.map((l, i) => (
                  <TranscriptLine key={l.t} speaker={l.sp} slot={l.slot} unnamed={l.unnamed} draft={l.draft} active={i === 1} time={l.t} text={l.x} onSeek={() => {}} />
                ))}
              </div>
              <div style={{ padding: "var(--space-4)", borderTop: "1px solid var(--border-hairline)", display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
                  <IconButton icon="play" title="Tocar" size={26} />
                  <div style={{ flex: 1, height: 3, borderRadius: 2, background: "var(--paper-3)" }}>
                    <div style={{ width: "42%", height: "100%", borderRadius: 2, background: "var(--accent)" }} />
                  </div>
                  <TimeCode>12:04</TimeCode>
                </div>
                <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>parakeet-tdt-0.6b-v3 · rascunho ao vivo · refino no encerramento</div>
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
