// The "Select optional features" page of Calamares (see docs/installer.md).
//
// It shows a checkbox for every choice in /usr/share/debian-livecd-installer, from features-model.js, which the build writes with lb/debian-livecd-installer-build/adapter-feature-model.sh.
// Two rules keep the choices consistent while the page is shown:
//  - Any choice that depends on another choice being enabled is placed as a tree, automatically deselecting/enabling features for the subchoice.
//  - A choice that needs one of several others is grayed out if none of them are enabled.
// NOTE: The below code is AI-generated.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "features-model.js" as Model

Item {
    id: page

    readonly property var choices: {
        const all = []
        for (const section of Model.sections)
            all.push(...section.choices)
        return all
    }
    readonly property var byId: {
        const map = {}
        for (const choice of choices)
            map[choice.id] = choice
        return map
    }
    // Whether each choice is checked, by id.
    // Every change replaces the whole object, because QML notices when picked gets a new object, not when a key inside the same object changes.
    property var picked: {
        const map = {}
        for (const choice of choices)
            map[choice.id] = choice.checked
        return map
    }
    // The checked choices, grouped under their section's label, with a section that has nothing checked left out instead of kept as an empty group
    readonly property var checkedSections: {
        const sections = []
        for (const section of Model.sections) {
            const checked = section.choices.filter(choice => picked[choice.id])
            if (checked.length > 0)
                sections.push({ label: section.label, choices: checked })
        }
        return sections
    }
    onCheckedSectionsChanged: config.packageChoice = answer(checkedSections)
    Component.onCompleted: config.packageChoice = answer(checkedSections)

    // The section that a choice belongs to, which is the first part of its id, everything before the "/"
    function sectionOf(id) {
        return id.split("/")[0]
    }
    // The one other choice that this choice depends on, or nothing when it needs none or one of several
    function soleRequirement(choice) {
        if (choice.requires.length !== 1)
            return undefined
        return byId[choice.requires[0]]
    }
    // The choice's parent in the tree of choices: the one other choice it needs when that is in the same section, otherwise nothing
    function parentOf(choice) {
        const required = soleRequirement(choice)
        if (required && sectionOf(required.id) === sectionOf(choice.id))
            return required
        return undefined
    }
    // Follows step, a function that gives the next choice for a choice, from the given choice, and returns every choice it visits, in order.
    // It stops when step gives nothing or a choice already in the list, so that choices that need each other in a loop do not make it go round forever.
    function chain(choice, step) {
        const list = [choice]
        let link = step(choice)
        while (link && !list.includes(link)) {
            list.push(link)
            link = step(link)
        }
        return list
    }
    function depth(choice) {
        return chain(choice, parentOf).length - 1
    }
    // Whether a choice can be checked right now: it needs nothing or exactly one other choice, or it needs one of several and at least one of them is checked
    function available(choice) {
        return choice.requires.length < 2 || choice.requires.some(id => picked[id])
    }
    // The labels of the sections holding the choices that this section's unavailable choices are waiting for, each label once
    function needed(section) {
        const labels = new Set()
        for (const choice of section.choices.filter(choice => !available(choice))) {
            for (const id of choice.requires) {
                const required = Model.sections.find(other => other.id === sectionOf(id))
                if (required)
                    labels.add(required.label)
            }
        }
        return Array.from(labels)
    }

    function toggle(choice, checked) {
        const next = Object.assign({}, picked)
        next[choice.id] = checked
        // Checking a choice also checks what it cannot work without: the one choice it depends on, then the one that one depends on, and so on.
        // It stops at a choice that needs nothing, at one that needs one of several because it cannot guess which, and at a choice it already checked, as when two choices need each other.
        if (checked) {
            for (const required of chain(choice, soleRequirement))
                next[required.id] = true
        }
        // Unchecks every checked choice that needs something but has none of it checked, searching again after each, because unchecking one can leave another without what it needs
        const unmet = other => next[other.id] && other.requires.length > 0 && !other.requires.some(id => next[id])
        let stranded = choices.find(unmet)
        while (stranded) {
            next[stranded.id] = false
            stranded = choices.find(unmet)
        }
        picked = next
    }

    // Turns the checked sections into one string: "none" when nothing is checked, otherwise an invisible HTML comment with the ids written as ",a/x,b/y,", then a bullet for each section's label with its checked choices' labels as bullets under it.
    // The inner lists set normal weight so that only the section labels are bold, and the outer list has no bottom margin, which removes a gap between the last section's label and its choices.
    function answer(sections) {
        if (sections.length === 0)
            return "none"
        let ids = ","
        let list = ""
        for (const section of sections) {
            let items = ""
            for (const choice of section.choices) {
                ids += `${choice.id},`
                items += `<li>${html(choice.label)}</li>`
            }
            list += `<li>${html(section.label)}<ul style="font-weight:normal">${items}</ul></li>`
        }
        return `<!--${ids}--><ul style="margin-bottom:0px">${list}</ul>`
    }
    // Turns text into HTML, replacing & < > and also ' and , with their codes, which still show as the same characters.
    // That way the answer has no ' anywhere, and its only commas are the ones around the ids in its HTML comment.
    function html(text) {
        const codes = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", ",": "&#44;" }
        let result = ""
        for (const character of text)
            result += codes[character] || character
        return result
    }

    // A Label that fills the width of its column, and moves text that does not fit onto more lines, breaking between words
    component WrappedLabel: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 14

            WrappedLabel {
                text: "Customize the optional features to install."
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
                    WrappedLabel {
                        visible: text !== ""
                        opacity: 0.7
                        text: section.modelData.description
                    }
                    WrappedLabel {
                        readonly property var needed: page.needed(section.modelData)
                        visible: needed.length > 0
                        opacity: 0.7
                        font.italic: true
                        text: "Requires one of the " + needed.join(" or ") + " to be enabled."
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
                                // A click does not check the box itself but asks the page to, because a box that checks itself loses its checked binding and stops following the page
                                checkable: false
                                checked: item.checked
                                enabled: item.usable
                                onClicked: page.toggle(item.modelData, !item.checked)
                            }
                            WrappedLabel {
                                Layout.leftMargin: item.textIndent
                                visible: text !== ""
                                opacity: item.usable ? 0.7 : 0.4
                                text: item.modelData.description
                            }
                            WrappedLabel {
                                Layout.leftMargin: item.textIndent
                                visible: !item.checked && item.modelData.warn !== ""
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
