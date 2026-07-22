# Bridge

**Intent:** split an abstraction from its implementations so both can vary independently.

Use when two dimensions would otherwise form a growing subclass matrix, such as message type × delivery channel.

```ts
interface Sender {
  send(text: string): void;
}
class EmailSender implements Sender {
  send(text: string) {
    console.log(`email: ${text}`);
  }
}
class SmsSender implements Sender {
  send(text: string) {
    console.log(`sms: ${text}`);
  }
}
class Alert {
  constructor(protected readonly sender: Sender) {}
  notify(text: string) {
    this.sender.send(`[alert] ${text}`);
  }
}
class UrgentAlert extends Alert {
  notify(text: string) {
    this.sender.send(`[urgent] ${text.toUpperCase()}`);
  }
}
```

Model each independently changing axis as one hierarchy or interface. Prefer direct composition if there is only one stable abstraction.

Source and diagrams: <https://refactoring.guru/design-patterns/bridge>
