import LocalTime from "local-time";

LocalTime.start();

document.addEventListener("turbo:morph", () => {
  LocalTime.run();
});

document.addEventListener('turbo:load', () => { LocalTime.run(); });
