import QtQml 2.13
import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Shapes 1.13

Slider {
    id: root

    property var chapters
    property bool seekStarted: false

    from: 0
    to: 99999

    background: Rectangle {
        id: progressBarBackground
        color: systemPalette.base
        implicitWidth: 200
        implicitHeight: 25
        height: implicitHeight
        radius: 0
        width: availableWidth
        x: leftPadding
        y: topPadding + availableHeight / 2 - height / 2

        Rectangle {
            color: systemPalette.highlight
            radius: 0
            height: parent.height
            width: visualPosition * parent.width
        }

        ToolTip {
            id: progressBarToolTip

            visible: false
            timeout: -1
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.MiddleButton | Qt.RightButton

            onClicked: {
                if (mouse.button === Qt.MiddleButton) {
                    var time = mouseX * 100 / progressBarBackground.width * root.to / 100
                    var chapters = mpv.getProperty("chapter-list")
                    const nextChapterTime = chapters.find(chapter => chapter.time > time )
                    mpv.setProperty("time-pos", mpv.formatTime(nextChapterTime.time))
                }
                if (mouse.button === Qt.RightButton && chaptersMenu.count > 0) {
                    chaptersMenu.popup(mouse.x-chaptersMenu.width * 0.5, -(chaptersMenu.count * chaptersMenu.menuItemHeight + 15))
                }
            }

            onMouseXChanged: {
                progressBarToolTip.x = mouseX - (progressBarToolTip.width * 0.5)

                var time = mouseX * 100 / progressBarBackground.width * root.to / 100
                progressBarToolTip.text = mpv.formatTime(time)
            }

            onEntered: {
                progressBarToolTip.visible = true
                progressBarToolTip.x = mouseX - (progressBarToolTip.width * 0.5)
                progressBarToolTip.y = root.height
            }

            onExited: progressBarToolTip.visible = false
        }
    }

    Instantiator {
        id: chaptersInstantiator
        model: chapters
        delegate: Shape {
            id: chapterMarkerShape
            property int position: modelData.time * 100 / root.to * progressBarBackground.width / 100
            antialiasing: true
            parent: progressBarBackground
            ShapePath {
                strokeWidth: 1
                strokeColor: systemPalette.text
                startX: chapterMarkerShape.position
                startY: root.height
                fillColor: systemPalette.text
                PathLine { x: chapterMarkerShape.position; y: -1 }
                PathLine { x: chapterMarkerShape.position + 6; y: -7 }
                PathLine { x: chapterMarkerShape.position - 7; y: -7 }
                PathLine { x: chapterMarkerShape.position - 1; y: -1 }
            }
            Rectangle {
                x: chapterMarkerShape.position - 8
                y: -11
                width: 15
                height: 11
                color: "transparent"
                ToolTip {
                    id: chapterTitleToolTip
                    text: modelData.title
                    visible: false
                    delay: 0
                    timeout: 10000
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: chapterTitleToolTip.visible = true
                    onExited: chapterTitleToolTip.visible = false
                }
            }
        }
    }

    handle: Rectangle {
        border.color: systemPalette.light
        color: systemPalette.light
        implicitWidth: 0
        implicitHeight: 35
        radius: 0
        x: leftPadding + visualPosition * (availableWidth - width)
        y: topPadding + availableHeight / 2 - height / 2
    }

    onPressedChanged: {
        if (pressed) {
            seekStarted = true
        } else {
            mpv.command(["seek", value, "absolute"])
            seekStarted = false
        }
    }

    Menu {
        id: chaptersMenu

        property int menuItemHeight
        property var checkedItem

        width: 0
        modal: true

        Instantiator {
            model: root.chapters
            delegate: MenuItem {
                id: menuitem

                checkable: true
                checked: index === chaptersMenu.checkedItem
                text: `${mpv.formatTime(modelData.time)} - ${modelData.title}`
                Component.onCompleted: {
                    chaptersMenu.width = menuitem.width > chaptersMenu.width
                            ? menuitem.width
                            : chaptersMenu.width
                    chaptersMenu.menuItemHeight = height
                }
                onClicked: {
                    mpv.setProperty("time-pos", modelData.time + 0.1)
                }
            }
            onObjectAdded: chaptersMenu.insertItem(index, object)
            onObjectRemoved: chaptersMenu.removeItem(object)
        }
    }

    Connections {
        target: mpv
        onFileLoaded: chapters = mpv.getProperty("chapter-list")
        onChapterChanged: {
            chaptersMenu.checkedItem = mpv.chapter

            var chapters = mpv.getProperty("chapter-list")
            var skipChaptersWords = settings.get("Playback", "SkipChaptersWordList")
            if (chapters.length === 0 || skipChaptersWords === "") {
                return
            }

            var words = skipChaptersWords.split(",")
            for (var i = 0; i < words.length; ++i) {
                if (chapters[mpv.chapter].title.toLowerCase().includes(words[i].trim())) {
                    actions.seekNextChapterAction.trigger()
                    if (settings.get("Playback", "ShowOsdOnSkipChapters")) {
                        osd.message(`Skipped chapter: ${chapters[mpv.chapter].title}`)
                    }
                    // a chapter title can match multiple words
                    // return to prevent skipping multiple chapters
                    return
                }
            }
        }
    }
}