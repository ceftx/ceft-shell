pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Qué panel de la barra está abierto ("" = ninguno). Solo uno a la vez.
Singleton {
  property string current: ""
  function toggle(name) { current = current === name ? "" : name }
  function close() { current = "" }

  // Ventana de configuración de red: "" = cerrada, si no, la pestaña abierta
  property string netSettings: ""
  function openNetSettings(tab) { current = ""; netSettings = tab || "summary" }
  function closeNetSettings() { netSettings = "" }

  // qs ipc call popup toggle audio|network|bluetooth|agent
  IpcHandler {
    target: "popup"
    function toggle(name: string): void { PopupState.toggle(name) }
    function close(): void { PopupState.close() }
  }
}
