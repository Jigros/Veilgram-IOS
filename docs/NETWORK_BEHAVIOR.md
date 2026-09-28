# Network behavior research

No Veilgram network hook exists yet. The table specifies hypotheses to trace in current TelegramCore and verify with a second account. A local UI indicator cannot verify a suppressed request.

| Feature | Telegram request/update | Normal behavior | Intended Veilgram behavior |
|---|---|---|---|
| Message read | read-history/content read path: exact current method pending source trace | recipient can learn read state | suppress selected acknowledgement when enabled, preserve explicit manual read |
| Story view | story view path: exact current method pending source trace | author may see view | suppress eligible acknowledgement; reactions/replies may reveal it server-side |
| Typing/recording/uploading | send-action path: exact current method pending source trace | peer sees activity | suppress selected action updates |
| Online | presence path: exact current method pending source trace | contacts may observe status | suppress eligible client updates; send and other server actions can still reveal activity |

Ghost behavior in [AyuGram documentation](https://github.com/AyuGram/AyuGramDocs/blob/main/shared/ghost.md) explicitly warns of server-side limits. Trace exact functions and request names at pinned SHA before changing code. Test account combinations, reconnect, multi-device and off-state behavior.
