# Instant AR Canvas #

This project is for Stanford EE 267 course project. The primary goal of this project is to adopt the iPad + Apple Pencil ecosystem as a mature sketching platform, while introducing minimal and accessible add-ons to produce a preliminary XR sketch experiential prototype.

In order to run this project, you need to 3D print a tracker and 2D print markers to fabricate a the traker. Both files are includede inside the project. The detail can be obtained through the written document.
You also need to build the iOS App inside Xcode. The minimum setup is iPad + Apple Pencil Pro with iOS version >= 17.5. The app need one addtional OpenCV package add-on, which we used a third party one bridged both opencv and opencv-contrib to swift (https://github.com/r0ml/OpenCV.git). You can directly manage this package through Xcode Swift Package Management (SPM), and the detail can be obtain through their github page. 

Once you have done these setups and use the tracker accordingly, you will be able to do the AR sketch instantly with you devices!
