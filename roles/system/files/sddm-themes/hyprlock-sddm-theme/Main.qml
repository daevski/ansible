import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080

    // Catppuccin Frappé colors
    property string textColor: "#c6d0f5"
    property string lavenderColor: "#80c8ff"
    property string baseColor: "#303446"
    property string crustColor: "#232634"
    property string greenColor: "#a6d189"
    property string redColor: "#e78284"
    property string peachColor: "#ef9f76"

    // Background image
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
        smooth: true
    }

    // Blur and darken overlay for better readability
    Rectangle {
        anchors.fill: parent
        color: crustColor
        opacity: 0.4
    }

    // Time display
    Text {
        id: timeText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.25

        text: Qt.formatTime(new Date(), "hh:mm")
        color: textColor
        font.family: "AudioLink Mono"
        font.pixelSize: 120
        font.weight: Font.Light

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm")
        }
    }

    // Date display
    Text {
        id: dateText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: timeText.bottom
        anchors.topMargin: -20

        text: Qt.formatDate(new Date(), "dddd, MMMM d")
        color: textColor
        font.family: "AudioLink Mono"
        font.pixelSize: 24
        font.weight: Font.Normal
    }

    // Login container
    Rectangle {
        id: loginContainer
        anchors.centerIn: parent
        width: 400
        height: 200
        color: "transparent"

        // Username display
        Text {
            id: usernameText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: passwordBg.top
            anchors.bottomMargin: 40

            text: userModel.lastUser
            color: lavenderColor
            font.family: "AudioLink Mono"
            font.pixelSize: 18
        }

        // Password field background
        Rectangle {
            id: passwordBg
            anchors.centerIn: parent
            width: 300
            height: 50
            color: baseColor
            border.color: passwordField.activeFocus ? lavenderColor : lavenderColor
            border.width: 2
            radius: 0

            // Password input
            TextField {
                id: passwordField
                anchors.fill: parent
                anchors.margins: 10

                placeholderText: "Enter Password..."
                placeholderTextColor: textColor
                echoMode: TextInput.Password
                color: textColor
                selectionColor: lavenderColor
                selectedTextColor: baseColor

                font.family: "AudioLink Mono"
                font.pixelSize: 14

                background: Rectangle {
                    color: "transparent"
                }

                focus: true

                Keys.onReturnPressed: sddm.login(userModel.lastUser, passwordField.text, sessionContainer.currentIndex)
                Keys.onEnterPressed: sddm.login(userModel.lastUser, passwordField.text, sessionContainer.currentIndex)

                onAccepted: sddm.login(userModel.lastUser, passwordField.text, sessionContainer.currentIndex)
            }
        }

        // Login status message
        Text {
            id: statusText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: passwordBg.bottom
            anchors.topMargin: 20

            text: ""
            color: redColor
            font.family: "AudioLink Mono"
            font.pixelSize: 14

            Connections {
                target: sddm
                function onLoginFailed() {
                    statusText.text = "Authentication Failed"
                    statusText.color = redColor
                    passwordField.clear()
                }
                function onLoginSucceeded() {
                    statusText.text = ""
                }
            }
        }
    }

    // Session selector (bottom left) - clickable to cycle through sessions
    Rectangle {
        id: sessionContainer
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 40
        width: 250
        height: 40
        color: baseColor
        border.color: lavenderColor
        border.width: 1

        Row {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 10

            Text {
                width: parent.width - 30
                height: parent.height
                text: sessionModel.data(sessionModel.index(sessionSelect.currentIndex, 0), 257)
                color: textColor
                font.family: "AudioLink Mono"
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                leftPadding: 10
            }

            Text {
                width: 20
                height: parent.height
                text: "▼"
                color: lavenderColor
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
            }
        }

        property int currentIndex: sessionModel.lastIndex

        MouseArea {
            id: sessionSelect
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            property int currentIndex: sessionContainer.currentIndex

            onClicked: {
                // Cycle through available sessions
                sessionContainer.currentIndex = (sessionContainer.currentIndex + 1) % sessionModel.rowCount()
                sessionSelect.currentIndex = sessionContainer.currentIndex
            }
        }
    }

    // Power buttons (bottom right)
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 40
        spacing: 20

        // Reboot button
        Rectangle {
            width: 40
            height: 40
            color: baseColor
            border.color: lavenderColor
            border.width: 1
            radius: 0

            Text {
                anchors.centerIn: parent
                text: "⟳"
                color: textColor
                font.pixelSize: 24
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }

        // Shutdown button
        Rectangle {
            width: 40
            height: 40
            color: baseColor
            border.color: lavenderColor
            border.width: 1
            radius: 0

            Text {
                anchors.centerIn: parent
                text: "⏻"
                color: textColor
                font.pixelSize: 24
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }

    Component.onCompleted: {
        passwordField.forceActiveFocus()
    }
}
