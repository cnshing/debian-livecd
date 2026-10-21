// The "Select optional features" page of Calamares (see docs/installer.md).
//
// It shows a checkbox for every choice in /usr/share/debian-livecd-installer, from features-model.js, which the build writes with lb/debian-livecd-installer-build/adapter-feature-model.sh
// Two rules keep the choices consistent while the page is shown:
//  - Any choices that is dependent on another choice being enabled is placed as a tree, Automatically deselecting/enabling features for the subchoice.
//  - A choice that needs one of several others is grayed out if none of them are enabled.
// NOTE: The below code is AI-generated.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "features-model.js" as Model

Item {
    id: page

    readonly property var choices: Model.sections.reduce((all, section) => all.concat(section.choices), [])
    readonly property var byId: { const m = {}; for (const c of choices) m[c.id] = c; return m }
    // Whether each choice is checked, by id. Replaced on every change, so that the bindings update.
    property var picked: { const m = {}; for (const c of choices) m[c.id] = c.checked; return m }

    // The choice it is drawn under: the one choice it needs, when that is in the same section
    function parentOf(c) {
        const p = c.requires.length === 1 ? byId[c.requires[0]] : undefined
        return p && p.id.split("/")[0] === c.id.split("/")[0] ? p : undefined
    }
    function depth(c) { let d = 0; for (let p = parentOf(c); p; p = parentOf(p)) d++; return d }
    function available(c) { return c.requires.length < 2 || c.requires.some(r => picked[r]) }
    // The labels of the sections whose choices the grayed out choices of a section need
    function needed(section) {
        const labels = []
        for (const c of section.choices.filter(c => !available(c)))
            for (const r of c.requires) {
                const s = Model.sections.find(s => s.id === r.split("/")[0])
                if (s && !labels.includes(s.label)) labels.push(s.label)
            }
        return labels
    }

    function toggle(c, checked) {
        const next = Object.assign({}, picked)
        next[c.id] = checked
        // Checking a choice checks what it needs, when that is one choice
        for (let r = c; checked && r.requires.length === 1 && byId[r.requires[0]]; r = byId[r.requires[0]])
            next[r.requires[0]] = true
        // Unchecks the choices left without anything they need, until there are none
        for (let changed = true; changed;) {
            changed = false
            for (const other of choices) {
                if (next[other.id] && other.requires.length && !other.requires.some(r => next[r])) {
                    next[other.id] = false
                    changed = true
                }
            }
        }
        picked = next
    }

    // Passes the checked choices, which Calamares also lists on its summary page, or "none": Calamares keeps no empty
    // answer, and runs no command whose ${gs[...]} it does not have
    function publish() {
        config.packageChoice = choices.filter(c => picked[c.id]).map(c => c.id).join(",") || "none"
    }
    onPickedChanged: publish()
    Component.onCompleted: publish()

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 14

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Choose the optional features to install. Everything else of the live system is always installed."
            }

            Repeater {
                model: Model.sections
                delegate: ColumnLayout {
                    id: section
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: section.modelData.label
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        text: section.modelData.description
                    }
                    Label {
                        readonly property var needed: page.needed(section.modelData)
                        Layout.fillWidth: true
                        visible: needed.length > 0
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        font.italic: true
                        text: "Needs one of the " + needed.join(" or ") + "."
                    }

                    Repeater {
                        model: section.modelData.choices
                        delegate: ColumnLayout {
                            id: item
                            required property var modelData
                            readonly property bool checked: page.picked[modelData.id] === true
                            readonly property bool usable: page.available(modelData)
                            readonly property real textIndent: box.leftPadding + box.indicator.width + box.spacing
                            Layout.fillWidth: true
                            Layout.leftMargin: page.depth(modelData) * 28
                            spacing: 0

                            CheckBox {
                                id: box
                                text: item.modelData.label
                                // The page sets checked, so that a click does not break its binding
                                checkable: false
                                checked: item.checked
                                enabled: item.usable
                                onClicked: page.toggle(item.modelData, !item.checked)
                            }
                            Label {
                                Layout.fillWidth: true
                                Layout.leftMargin: item.textIndent
                                visible: text !== ""
                                wrapMode: Text.WordWrap
                                opacity: item.usable ? 0.7 : 0.4
                                text: item.modelData.description
                            }
                            Label {
                                Layout.fillWidth: true
                                Layout.leftMargin: item.textIndent
                                visible: !item.checked && item.modelData.warn !== ""
                                wrapMode: Text.WordWrap
                                color: "#9c6e03"
                                text: item.modelData.warn
                            }
                        }
                    }
                }
            }
        }
    }
}
