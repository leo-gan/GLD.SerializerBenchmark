package benchmark.model.v2;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class Event implements Serializable {
  private static final long serialVersionUID = 1L;

  public String eventId;
  public String eventType;
  public long occurredAt;
  public String producer;
  public List<EventAttr> attrs = new ArrayList<>();

  public Event() {}

  public Event(
      String eventId, String eventType, long occurredAt, String producer, List<EventAttr> attrs) {
    this.eventId = eventId;
    this.eventType = eventType;
    this.occurredAt = occurredAt;
    this.producer = producer;
    this.attrs = attrs != null ? attrs : new ArrayList<>();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Event e)) return false;
    return occurredAt == e.occurredAt
        && Objects.equals(eventId, e.eventId)
        && Objects.equals(eventType, e.eventType)
        && Objects.equals(producer, e.producer)
        && Objects.equals(attrs, e.attrs);
  }

  @Override
  public int hashCode() {
    return Objects.hash(eventId, eventType, occurredAt, producer, attrs);
  }

  public static final class EventAttr implements Serializable {
    private static final long serialVersionUID = 1L;
    public String key;
    public String value;

    public EventAttr() {}

    public EventAttr(String key, String value) {
      this.key = key;
      this.value = value;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof EventAttr a)) return false;
      return Objects.equals(key, a.key) && Objects.equals(value, a.value);
    }

    @Override
    public int hashCode() {
      return Objects.hash(key, value);
    }
  }
}
