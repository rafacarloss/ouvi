Immediate on/off for settings that take effect at once (cloud LLM, launch at login, keep audio).

```jsx
<Switch checked={cloud} onChange={setCloud} label="Permitir Claude API" />
```

Use `Checkbox` when the change needs a Save, `Switch` when it does not.
