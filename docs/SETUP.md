# Duit: setup and run guide (Windows)

This guide takes you from a fresh Windows PC to Duit running on your phone or an emulator.
Part 1 is done only once (about 45 to 60 minutes, mostly downloads).

---

## Part 1: Install the tools (one time)

### 1. Install Git
Flutter uses Git to download and update itself.

1. Download **Git for Windows** from https://git-scm.com/download/win and run the installer.
2. Keep all the default options.

### 2. Install Android Studio
Android Studio gives you the Android SDK (the tools that build Android apps) and the emulator.

1. Download it from https://developer.android.com/studio and install with the default options.
2. Open Android Studio. In the setup wizard choose **Standard** and let it download everything.
3. On the welcome screen, click **More Actions > SDK Manager**.
4. Open the **SDK Tools** tab, tick **Android SDK Command-line Tools (latest)**, and click **Apply**.

### 3. Install Flutter
1. Go to https://docs.flutter.dev/get-started/install/windows/mobile and download the latest **stable** Flutter SDK zip.
2. Create the folder `C:\dev` and extract the zip there, so you get `C:\dev\flutter`.
   Do not put Flutter in `C:\Program Files` or any path with spaces.
3. Add Flutter to your PATH so the `flutter` command works anywhere:
   1. Press Start, type **environment**, and open **Edit environment variables for your account**.
   2. Select **Path**, click **Edit**, then **New**, and add `C:\dev\flutter\bin`.
   3. Click **OK** on every window.
4. Close any open terminals and open a new **PowerShell** window.

### 4. Turn on Developer Mode in Windows
Flutter plugins (like the database) need this on Windows.

1. In PowerShell run: `start ms-settings:developers`
2. Turn **Developer Mode** on.

### 5. Check everything with flutter doctor
In a new PowerShell window run:

```powershell
flutter doctor
flutter doctor --android-licenses
```

Type `y` to accept each licence. Run `flutter doctor` again. You need green ticks for
**Flutter** and **Android toolchain**. Warnings about Chrome, Visual Studio or Windows desktop are fine to ignore.

### 6. (Recommended) Set up VS Code
You already have VS Code. Install the **Flutter** extension (it adds Dart too). Open the `duit`
folder with **File > Open Folder** to edit the code, and use **Terminal > New Terminal** to run commands.

### 7. Get a device to run on
Pick one:

**Your Android phone (fastest)**
1. On the phone, open **Settings > About phone** and tap **Build number** 7 times to unlock Developer options.
2. Open **Settings > System > Developer options** (the location varies by brand) and turn on **USB debugging**.
3. Plug the phone into your PC with a USB cable and tap **Allow** on the phone when asked.

**Emulator**
1. In Android Studio, open **More Actions > Virtual Device Manager**.
2. Click **Create device**, pick **Pixel 8**, choose the newest system image (download it), and finish.
3. Press the play button to start it.

Check that Flutter sees the device:

```powershell
flutter devices
```

---

## Part 2: Create and run the project

The app code is already in `Documents\duit`. These steps add the Android project files around it
and generate the database code.

Open PowerShell (or the VS Code terminal) and run:

```powershell
cd $HOME\Documents\duit

# 1. Add the Android project files. Existing files (lib, pubspec.yaml) are kept.
flutter create --org com.duitapp --project-name duit --platforms android .

# 2. Remove the sample test that flutter create adds (it tests a counter app we don't have)
Remove-Item test\widget_test.dart

# 3. Download the packages
flutter pub get

# 4. Generate the database code (creates lib/data/db/app_database.g.dart)
dart run build_runner build --delete-conflicting-outputs

# 5. Run the logic tests
flutter test

# 6. Run the app on your phone or emulator
flutter run
```

The first `flutter run` takes 5 to 10 minutes because Gradle downloads Android build tools. Later runs are much faster.

While the app is running, press `r` in the terminal to hot reload after a code change, `R` to restart, and `q` to quit.

### When to run build_runner again
Run step 4 again whenever you change `lib/data/db/tables.dart` or `app_database.dart`.

---

## Troubleshooting

| Message | Fix |
| --- | --- |
| `'flutter' is not recognized` | The PATH step did not work. Recheck step 3 and open a new terminal. |
| `Target of URI hasn't been generated: app_database.g.dart` | Run `dart run build_runner build --delete-conflicting-outputs`. |
| `Building with plugins requires symlink support` | Turn on Developer Mode (Part 1, step 4). |
| `requires Android NDK ...` or `ndkVersion` | The message shows a line to paste into `android/app/build.gradle.kts`. Do that, or send me the message. |
| `version solving failed` | Send me the full message and I'll adjust the package versions. |
| `No devices found` | Unlock the phone and allow USB debugging, or start the emulator first. |

If anything else goes wrong, copy the full error from the terminal and send it to me.
