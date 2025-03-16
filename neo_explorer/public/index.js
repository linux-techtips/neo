import { Editor, Output, Stats, Window } from "./scripts/components.js";
import { Neo } from "./scripts/neo.js";

window.neo = new Neo();

customElements.define("ui-editor", Editor);
customElements.define("ui-stats", Stats);
customElements.define("ui-output", Output);

customElements.define("ui-window", Window);
