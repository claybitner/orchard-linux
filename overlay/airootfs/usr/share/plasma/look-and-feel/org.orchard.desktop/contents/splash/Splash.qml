import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#17213f"

    property int stage

    Image {
        anchors.fill: parent
        source: "file:///usr/share/wallpapers/macbook-cachyos/orchard-dusk.svg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 9
        height: Kirigami.Units.gridUnit * 12
        opacity: root.stage > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        Image {
            id: logo
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: Kirigami.Units.gridUnit * 6
            height: width
            source: "file:///usr/share/icons/hicolor/scalable/apps/orchard-menu.svg"
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
        }

        BusyIndicator {
            anchors {
                top: logo.bottom
                topMargin: Kirigami.Units.gridUnit
                horizontalCenter: parent.horizontalCenter
            }
            width: Kirigami.Units.gridUnit * 2
            height: width
            running: root.stage < 6
        }
    }

    component BusyIndicator: Item {
        property bool running: true

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 3
            radius: height / 2
            color: "#4dffffff"

            Rectangle {
                width: parent.width * Math.max(0.12, Math.min(1, root.stage / 6))
                height: parent.height
                radius: parent.radius
                color: "#ffffff"

                Behavior on width {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
