import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

import org.kde.taskmanager 0.1 as TaskManager
import org.kde.plasma.private.taskmanager 0.1 as TaskManagerApplet

import "../code/tools.js" as TaskTools

Item {
    id:panel

    Layout.fillHeight: true
    Layout.fillWidth: true

    property bool debugLocation: false

    property bool dropNewLauncher: false
    property bool enableShadows: plasmoid.configuration.showShadows
    property bool glow: plasmoid.configuration.showGlow
    property bool initializationStep: true
    property bool initializatedBuffers: noInitCreatedBuffers >= tasksStarting ? true : false
    property bool isHovered: false
    property bool showBarLine: plasmoid.configuration.showBarLine
    property bool taskInAnimation: noTasksInAnimation > 0 ? true : false
    property bool vertical: ((panel.position === PlasmaCore.Types.LeftPositioned) ||
                             (panel.position === PlasmaCore.Types.RightPositioned)) ? true : false

    property int clearWidth
    property int clearHeight
    property int iconSize: Math.max(plasmoid.configuration.iconSize, 16)
    property int iconMargin: 5
    property int newLocationDebugUse: PlasmaCore.Types.BottomPositioned
    property int newDroppedPosition: -1;
    property int noInitCreatedBuffers: 0;
    property int noTasksInAnimation: 0
    property int position : PlasmaCore.Types.BottomPositioned
    property int tasksStarting: 0;
    property int realSize: iconSize + iconMargin
    property int statesLineSize: Math.ceil( panel.iconSize/13 )

  //  property real backColorLuma: 0.2126*theme.backgroundColor.r + 0.7152*theme.backgroundColor.g + 0.0722*theme.backgroundColor.b
    property real zoomFactor: ( 1 + (plasmoid.configuration.zoomLevel / 20) )
    property real textColorLuma: 0.2126*theme.textColor.r + 0.7152*theme.textColor.g + 0.0722*theme.textColor.b

    property QtObject contextMenuComponent: Qt.createComponent("ContextMenu.qml");
    property Item dragSource: null

    property color minimizedDotColor: textColorLuma > 0.5 ? Qt.darker(theme.textColor, 1+ (1-textColorLuma)) : Qt.lighter(theme.textColor, 1+(1-textColorLuma))
  //  property color shownDotColor: backColorLuma < 0.5 ? Qt.lighter(theme.backgroundColor, 1+Math.abs(1-backColorLuma)) : Qt.darker(theme.backgroundColor, 1+backColorLuma/4)

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground   

    signal requestLayout
    signal windowsHovered(variant winIds, bool hovered)
    signal presentWindows(variant winIds)
    signal draggingFinished();

    /*Rectangle{
                anchors.fill: parent
                border.width: 1
                border.color: "red"
                color: "white"
            }*/

    Connections {
        target: plasmoid
        onLocationChanged: {
            panel.updatePosition();
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: plasmoid.configuration

        onLaunchersChanged: tasksModel.launcherList = plasmoid.configuration.launchers
        onGroupingAppIdBlacklistChanged: tasksModel.groupingAppIdBlacklist = plasmoid.configuration.groupingAppIdBlacklist;
        onGroupingLauncherUrlBlacklistChanged: tasksModel.groupingLauncherUrlBlacklist = plasmoid.configuration.groupingLauncherUrlBlacklist;
    }

    /////
    PlasmaCore.ColorScope{
        id: colorScopePalette
    }

    /////

    onDragSourceChanged: {
        if (dragSource == null) {
            panel.draggingFinished();

            tasksModel.syncLaunchers();
        }
    }

    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screen: plasmoid.screen
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: plasmoid.configuration.showOnlyCurrentActivity

        launchInPlace: true
        separateLaunchers: false
        groupInline: false

        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual

        onActivityChanged: {
            //panel.updateImplicits();
            //panelGeometryTimer.start();
        }

        onLauncherListChanged: {
            plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        onAnyTaskDemandsAttentionChanged: {
            if (anyTaskDemandsAttention){
                plasmoid.status = PlasmaCore.Types.RequiresAttentionStatus;
                attentionTimerComponent.createObject(panel);
            }
        }

        Component.onCompleted: {
            launcherList = plasmoid.configuration.launchers;
            groupingAppIdBlacklist = plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = plasmoid.configuration.groupingLauncherUrlBlacklist;

            icList.model = tasksModel;

            tasksStarting = count;
        }
    }

    TaskManagerApplet.Backend {
        id: backend

        taskManagerItem: panel
        //toolTipItem: toolTipDelegate
        //highlightWindows: plasmoid.configuration.highlightWindows

        onAddLauncher: {
            tasksModel.requestAddLauncher(url);
            // tasksModel.move(pos, newDroppedPosition);
        }
    }

    TaskManagerApplet.DragHelper {
        id: dragHelper

        dragIconSize: units.iconSizes.medium
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }


    /*  IconsModel{
        id: iconsmdl
    }*/

    Component{
        id: attentionTimerComponent
        Timer{
            id: attentionTimer
            interval:6500
            onTriggered: {
                plasmoid.status = PlasmaCore.Types.PassiveStatus;
                destroy();
            }
            Component.onCompleted: {
                start();
            }
        }
    }

    //Timer to check if the mouse is still inside the ListView
    Timer{
        id:checkListHovered
        repeat:false;
        interval:60;

        onTriggered: {
            var tasks = icList.contentItem.children;
            var lostMouse = true;

            //  console.debug("---------");
            for(var i=0; i<tasks.length; ++i){
                var task = tasks[i];
                //    console.debug(task.containsMouse);
                if(task){
                    if (task.containsMouse){
                        lostMouse = false;
                        break;
                    }
                }
            }

            if(lostMouse){
                //  console.log("Restore state....");
                icList.currentSpot = -1000;
                icList.hoveredIndex = -1;
            }

            interval = 60;
        }

        function startDuration( duration){
            interval = duration;

            start();
        }
    }


    ///Red Liner!!! show the upper needed limit for annimations
    Rectangle{
        anchors.horizontalCenter: !panel.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: panel.vertical ? parent.verticalCenter : undefined

        width: panel.vertical ? 1 : 2 * panel.iconSize
        height: panel.vertical ? 2 * panel.iconSize : 1
        color: "red"
        x: (panel.position === PlasmaCore.Types.LeftPositioned) ? neededSpace : parent.width - neededSpace
        y: (panel.position === PlasmaCore.Types.TopPositioned) ? neededSpace : parent.height - neededSpace
        visible: plasmoid.configuration.zoomHelper

        property int neededSpace: (zoomFactor+0.1)*iconSize + statesLineSize + 2
    }

    Item{
        id:barLine

        opacity: (tasksModel.count > 0) && panel.initializatedBuffers ? 1 : 0

        anchors.bottom: (panel.position === PlasmaCore.Types.BottomPositioned) ? parent.bottom : undefined
        anchors.top: (panel.position === PlasmaCore.Types.TopPositioned) ? parent.top : undefined
        anchors.left: (panel.position === PlasmaCore.Types.LeftPositioned) ? parent.left : undefined
        anchors.right: (panel.position === PlasmaCore.Types.RightPositioned) ? parent.right : undefined

        anchors.horizontalCenter: !parent.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: parent.vertical ? parent.verticalCenter : undefined

        width: ( icList.orientation === Qt.Horizontal ) ? icList.width + spacing : smallSize
        height: ( icList.orientation === Qt.Vertical ) ? icList.height + spacing : smallSize

        property int spacing: panel.iconSize / 2
        property int smallSize: Math.max(3.7*panel.statesLineSize, 16)

        Behavior on opacity{
            NumberAnimation { duration: 150 }
        }

        /// plasmoid's default panel
        BorderImage{
            anchors.fill:parent
            source: "../images/panel-west.png"
            border { left:8; right:8; top:8; bottom:8 }

            opacity: (plasmoid.configuration.showBarLine && !plasmoid.configuration.useThemePanel) ? 1 : 0

            visible: (opacity == 0) ? false : true

            horizontalTileMode: BorderImage.Stretch
            verticalTileMode: BorderImage.Stretch

            Behavior on opacity{
                NumberAnimation { duration: 200 }
            }
        }


        /// item which is used as anchors for the plasma's theme
        Item{
            id:belower

            width: (panel.position === PlasmaCore.Types.LeftPositioned) ? shadowsSvgItem.margins.left : shadowsSvgItem.margins.right
            height: (panel.position === PlasmaCore.Types.BottomPositioned)? shadowsSvgItem.margins.bottom : shadowsSvgItem.margins.top

            anchors.top: (panel.position === PlasmaCore.Types.BottomPositioned) ? parent.bottom : undefined
            anchors.bottom: (panel.position === PlasmaCore.Types.TopPositioned) ? parent.top : undefined
            anchors.right: (panel.position === PlasmaCore.Types.LeftPositioned) ? parent.left : undefined
            anchors.left: (panel.position === PlasmaCore.Types.RightPositioned) ? parent.right : undefined
        }


        /// the current theme's panel
        PlasmaCore.FrameSvgItem{
            id: shadowsSvgItem

            anchors.bottom: (panel.position === PlasmaCore.Types.BottomPositioned) ? belower.bottom : undefined
            anchors.top: (panel.position === PlasmaCore.Types.TopPositioned) ? belower.top : undefined
            anchors.left: (panel.position === PlasmaCore.Types.LeftPositioned) ? belower.left : undefined
            anchors.right: (panel.position === PlasmaCore.Types.RightPositioned) ? belower.right : undefined

            anchors.horizontalCenter: !panel.vertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter: panel.vertical ? parent.verticalCenter : undefined

            width: panel.vertical ? panelSize + margins.left + margins.right: parent.width
            height: panel.vertical ? parent.height : panelSize + margins.top + margins.bottom

            imagePath: "translucent/widgets/panel-background"
            prefix:"shadow"

            opacity: (plasmoid.configuration.showBarLine && plasmoid.configuration.useThemePanel) ? 1 : 0
            visible: (opacity == 0) ? false : true

            property int panelSize: ((panel.position === PlasmaCore.Types.BottomPositioned) ||
                                     (panel.position === PlasmaCore.Types.TopPositioned)) ?
                                        plasmoid.configuration.panelSize + belower.height:
                                        plasmoid.configuration.panelSize + belower.width

            Behavior on opacity{
                NumberAnimation { duration: 200 }
            }


            PlasmaCore.FrameSvgItem{
                anchors.margins: belower.width-1
                anchors.fill:parent
                imagePath: plasmoid.configuration.transparentPanel ? "translucent/widgets/panel-background" :
                                                                     "widgets/panel-background"
            }
        }


        MouseHandler {
            id: mouseHandler
            anchors.bottom: (panel.position === PlasmaCore.Types.BottomPositioned) ? icList.bottom : undefined
            anchors.top: (panel.position === PlasmaCore.Types.TopPositioned) ? icList.top : undefined
            anchors.left: (panel.position === PlasmaCore.Types.LeftPositioned) ? icList.left : undefined
            anchors.right: (panel.position === PlasmaCore.Types.RightPositioned) ? icList.right : undefined

            anchors.horizontalCenter: !panel.vertical ? icList.horizontalCenter : undefined
            anchors.verticalCenter: panel.vertical ? icList.verticalCenter : undefined

            width: panel.vertical ? maxSize : icList.width
            height: panel.vertical ? icList.height : maxSize

            target: icList.contentItem

            property int maxSize: panel.zoomFactor*panel.realSize + 16
        }


        ListView {
            id:icList

            //trigger updating scaling of neighbour delegates of zoomed delegate
            signal updateScale(int delegateIndex, real newScale, real step)
            signal mouseWasEntered(int delegateIndex, bool value);

            property int currentSpot : -1000
            property int hoveredIndex : -1
            property int previousCount : 0

            property bool delayingRemoval: false

            //  property int count: children ? children.length : 0
            anchors.bottom: (panel.position === PlasmaCore.Types.BottomPositioned) ? parent.bottom : undefined
            anchors.top: (panel.position === PlasmaCore.Types.TopPositioned) ? parent.top : undefined
            anchors.left: (panel.position === PlasmaCore.Types.LeftPositioned) ? parent.left : undefined
            anchors.right: (panel.position === PlasmaCore.Types.RightPositioned) ? parent.right : undefined

            anchors.horizontalCenter: !panel.vertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter: panel.vertical ? parent.verticalCenter : undefined

            width: contentWidth + 2
            height: contentHeight + 2

            orientation: Qt.Horizontal

            delegate: TaskDelegate{}

            /*Rectangle{
                anchors.fill: parent
                border.width: 1
                border.color: "red"
                color: "transparent"
            }*/

            //the duration of this animation should be as small as possible
            //it fixes a small issue with the dragging an item to change it's
            //position, if the duration is too big there is a point in the
            //list that an item is going back and forth too fast

            //more of a trouble
            moveDisplaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 60; easing.type: Easing.Linear }
            }

            ///this transition can not be used with dragging !!!! I breaks
            ///the lists indexes !!!!!
            /*  move:  Transition {
                NumberAnimation { properties: "x,y"; duration: 100; easing.type: Easing.Linear }
            } */
        }

        Item{
            id: newDroppedLauncherVisual
            anchors.fill: mouseHandler
            // width: panel.dropNewLauncher ? parent.width : 0
            // height: panel.dropNewLauncher ? parent.height : 0

            visible: opacity == 0 ? false : true
            opacity: panel.dropNewLauncher && (panel.dragSource == null) ? 1 : 0

            Behavior on opacity{
                NumberAnimation { duration: 200; }
            }

            Rectangle{
                anchors.fill: parent

                anchors.bottom: (panel.position === PlasmaCore.Types.TopPositioned) ? parent.bottom : undefined
                anchors.top: (panel.position === PlasmaCore.Types.BottomPositioned) ? parent.top : undefined
                anchors.left: (panel.position === PlasmaCore.Types.RightPositioned) ? parent.left : undefined
                anchors.right: (panel.position === PlasmaCore.Types.LeftPositioned) ? parent.right : undefined

                radius: panel.iconSize/8

                property color tempColor: "#aa222222"
                color: tempColor
                border.width: 1
                border.color: "#ff656565"

                property int crossSize: Math.min(parent.width/2, parent.height/2)

                Rectangle{width: parent.crossSize; height: 4; anchors.centerIn: parent; color: theme.highlightColor}
                Rectangle{width: 4; height: parent.crossSize; anchors.centerIn: parent; color: theme.highlightColor}
            }
        }
    }

    //// helpers

    Timer {
        id: iconGeometryTimer
        // INVESTIGATE: such big interval but unfortunately it doesnot work otherwise
        interval: 500
        repeat: false

        onTriggered: {
            //    console.debug("Found children: "+icList.contentItem.children.length);
            TaskTools.publishIconGeometries(icList.contentItem.children);
        }
    }

    function movePanel(obj, newPosition){
        var bLine = obj;
        if (newPosition === PlasmaCore.Types.BottomPositioned){
            bLine.anchors.horizontalCenter = bLine.parent.horizontalCenter;
            bLine.anchors.verticalCenter = undefined;
            bLine.anchors.bottom = bLine.parent.bottom;
            bLine.anchors.top = undefined;
            bLine.anchors.left = undefined;
            bLine.anchors.right = undefined;
        }
        else if (newPosition === PlasmaCore.Types.TopPositioned){
            bLine.anchors.horizontalCenter = bLine.parent.horizontalCenter;
            bLine.anchors.verticalCenter = undefined;
            bLine.anchors.bottom = undefined;
            bLine.anchors.top = bLine.parent.top;
            bLine.anchors.left = undefined;
            bLine.anchors.right = undefined;
        }
        else if (newPosition === PlasmaCore.Types.LeftPositioned){
            bLine.anchors.horizontalCenter = undefined;
            bLine.anchors.verticalCenter = bLine.parent.verticalCenter;
            bLine.anchors.bottom = undefined;
            bLine.anchors.top = undefined;
            bLine.anchors.left = bLine.parent.left;
            bLine.anchors.right = undefined;
        }
        else if (newPosition === PlasmaCore.Types.RightPositioned){
            bLine.anchors.horizontalCenter = undefined;
            bLine.anchors.verticalCenter = bLine.parent.verticalCenter;
            bLine.anchors.bottom = undefined;
            bLine.anchors.top = undefined;
            bLine.anchors.left =undefined;
            bLine.anchors.right = bLine.parent.right;
        }
    }

    property int ncounter:0

    function updateImplicits(){
        /*    if(icList.previousCount !== icList.count){
            icList.previousCount = icList.count;

            var zoomedLength = Math.floor( 1.7 * (iconSize+iconMargin) * (panel.zoomFactor));
            var bigAxis = (tasksModel.count-1) * (iconSize+iconMargin) + zoomedLength
            var smallAxis = zoomedLength + 1

            var clearBigAxis = tasksModel.count * (iconSize+iconMargin);
            var clearSmallAxis = (iconSize+iconMargin);

            //  debugging code
                 ncounter++;
                console.log("Implicits______ "+ncounter+". - "+tasksModel.count);

            if (panel.vertical){
                panel.implicitWidth = smallAxis;
                panel.implicitHeight = bigAxis;
                panel.clearWidth = clearSmallAxis;
                panel.clearHeight = clearBigAxis;
            }
            else{
                panel.implicitWidth = bigAxis;
                panel.implicitHeight = smallAxis;
                panel.clearWidth = clearBigAxis;
                panel.clearHeight = clearSmallAxis;
            }

            iconGeometryTimer.restart();
        }*/
    }

    PlasmaComponents.Button{
        id: orientationBtn
        text:"Orientation"

        anchors.centerIn: parent
        visible: panel.debugLocation

        onClicked:{
            switch(panel.position){
            case PlasmaCore.Types.BottomPositioned:
                panel.newLocationDebugUse = PlasmaCore.Types.LeftEdge;
                break;
            case PlasmaCore.Types.LeftPositioned:
                panel.newLocationDebugUse = PlasmaCore.Types.TopEdge;
                break;
            case PlasmaCore.Types.TopPositioned:
                panel.newLocationDebugUse = PlasmaCore.Types.RightEdge;
                break;
            case PlasmaCore.Types.RightPositioned:
                panel.newLocationDebugUse = PlasmaCore.Types.BottomEdge;
                break;
            }
            updatePosition();
        }
    }


    function updatePosition(){
        var newPosition;
        var tempVertical=false;

        var positionUsed;


        if (panel.debugLocation)
            positionUsed = panel.newLocationDebugUse;
        else
            positionUsed = plasmoid.location;

        switch (positionUsed) {
        case PlasmaCore.Types.LeftEdge:
            newPosition = PlasmaCore.Types.LeftPositioned;
            tempVertical = true;
            break;
        case PlasmaCore.Types.RightEdge:
            newPosition = PlasmaCore.Types.RightPositioned;
            tempVertical = true;
            break;
        case PlasmaCore.Types.TopEdge:
            newPosition = PlasmaCore.Types.TopPositioned;
            break;
        default:
            newPosition = PlasmaCore.Types.BottomPositioned;
            break
        }

        movePanel(barLine,newPosition);
        movePanel(icList,newPosition);

        if(tempVertical)
            icList.orientation = Qt.Vertical;
        else
            icList.orientation = Qt.Horizontal;

        panel.position = newPosition;
    }

    function hasLauncher(url) {
        return tasksModel.launcherPosition(url) != -1;
    }

    function addLauncher(url) {
        tasksModel.requestAddLauncher(url);
    }

    function resetDragSource() {
        dragSource = null;
    }

    Component.onCompleted:  {
        updatePosition();
        //   updateImplicits(); // the models items have not been added yet
        panel.presentWindows.connect(backend.presentWindows);
        mouseHandler.urlDropped.connect(backend.urlDropped);
        dragHelper.dropped.connect(resetDragSource);
        //    iconGeometryTimer.start();
    }

}
