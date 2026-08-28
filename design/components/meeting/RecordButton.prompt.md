The one green pill that starts and stops capture; also lives in the menu-bar dropdown at `size="sm"`.

```jsx
<RecordButton state="idle" onClick={start} />
<RecordButton state="recording" elapsed="12:04" onClick={stop} />
```

While recording it inverts to the soft green fill with a pulsing dot — never turns red.
