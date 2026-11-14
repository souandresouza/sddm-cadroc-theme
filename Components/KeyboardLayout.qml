import QtQuick 2.15

// Indicador do layout de teclado atual (ex.: "Portuguese (Brazil)").
// Só aparece quando há mais de um layout configurado no sistema, para não
// poluir a tela de quem usa um único layout.
Item {
    id: layoutItem

    readonly property var layouts: typeof keyboard !== "undefined" && keyboard.layouts
                                   ? keyboard.layouts : []
    readonly property string current: layouts.length > 1
                                      ? layouts[keyboard.currentLayout] : ""

    visible: config.ShowKeyboardLayout == "true" && current !== ""
    implicitHeight: visible ? layoutText.implicitHeight : 0

    Text {
        id: layoutText

        anchors.centerIn: parent
        text: layoutItem.current
        color: config.PlaceholderTextColor
        font.family: config.Font
        font.pointSize: Math.max(9, Math.round(root.font.pointSize * 0.75))
    }
}
