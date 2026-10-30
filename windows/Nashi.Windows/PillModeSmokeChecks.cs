#if DEBUG
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Runtime.InteropServices;
using Nashi.Core;

namespace Nashi.Windows;

internal static class PillModeSmokeChecks
{
    [StructLayout(LayoutKind.Sequential)] private struct NativePoint { internal int X,Y; }
    [StructLayout(LayoutKind.Sequential)] private struct NativeRect { internal int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] private static extern IntPtr WindowFromPoint(NativePoint point);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd,out NativeRect rect);
    internal static int Run(string output)
    {
        output=Path.GetFullPath(output);
        if(Directory.Exists(output)&&Directory.EnumerateFileSystemEntries(output).Any())throw new IOException("Choose an empty pill smoke-test output folder.");
        Directory.CreateDirectory(output);File.WriteAllText(Path.Combine(output,".nashi-pill-smoke"),"Nashi pill interaction smoke\n");
        var checks=new List<object>();var failures=new List<string>();void Check(string name,bool pass,string? detail=null){checks.Add(new{name,passed=pass,detail});if(!pass)failures.Add(name+(detail is null?"":": "+detail));}
        var data=Path.Combine(output,"isolated-data");Directory.CreateDirectory(data);var library=new LibraryStore(data);var preferences=new PreferencesStore(data);
        preferences.Save(new Preferences{Language="en",PillModeEnabled=true,PillVisibilityMode="automatic",PillHotkey="Ctrl+Alt+N",PillHotEdgeEnabled=true,AutomaticUpdateChecks=false,KeepInTray=false,Feedback=false,Animations=false});
        var window=new MainWindow(library:library,checkForUpdates:false,offerToolSetup:false);
        try
        {
            DesktopInput.MovePointer(new Point(SystemParameters.PrimaryScreenWidth-40,SystemParameters.PrimaryScreenHeight-90));
            window.Show();DesktopInput.Pump(450);
            Check("collapsed-at-start",window.IsVisible&&Math.Abs(window.ActualWidth-PillGeometry.CollapsedWidth)<1&&Math.Abs(window.ActualHeight-PillGeometry.CollapsedHeight)<1,$"visible={window.IsVisible}, size={window.ActualWidth:0}x{window.ActualHeight:0}");
            Check("single-shaped-root",window.UIAuditIslandTab=="now"&&window.Content is System.Windows.Controls.Border,"the pill did not use its single border root and Now view");
            Check("global-hotkey-registered",window.UIAuditHotkeyRegistered,"RegisterHotKey failed or the shortcut is already in use");
            var pickerFolder=Path.Combine(output,"pdf-picker-fixture");Directory.CreateDirectory(pickerFolder);var pixels=new byte[16*16*4];for(var y=0;y<16;y++)for(var x=0;x<16;x++){var offset=(y*16+x)*4;pixels[offset]=(byte)(x*16);pixels[offset+1]=(byte)(y*16);pixels[offset+2]=(byte)(255-x*16);pixels[offset+3]=255;}var fixtureImage=BitmapSource.Create(16,16,96,96,PixelFormats.Bgra32,null,pixels,16*4);fixtureImage.Freeze();var fixturePdf=Path.Combine(pickerFolder,"Synthetic edit.pdf");ImageEngine.Save(fixtureImage,fixturePdf,"pdf");File.WriteAllBytes(Path.Combine(pickerFolder,"Synthetic image.png"),[137,80,78,71]);File.WriteAllText(Path.Combine(pickerFolder,"Synthetic archive.zip"),"fixture");
            var pdfPicker=new NashiFilePickerWindow(window,pickerFolder,["pdf"],allowMultiple:false,purpose:"pdf");pdfPicker.Show();DesktopInput.Pump(250);var pdfPickerScoped=pdfPicker.UIAuditHasVisibleFile("Synthetic edit.pdf")&&!pdfPicker.UIAuditHasVisibleFile("Synthetic image.png")&&!pdfPicker.UIAuditHasVisibleFile("Synthetic archive.zip")&&pdfPicker.UIAuditSingleSelection;Check("pdf-tool-picker-is-scoped",pdfPickerScoped,"the PDF edit picker must show PDFs only and use single selection");if(pdfPickerScoped)Capture(pdfPicker,Path.Combine(output,"pdf-tool-picker.png"));pdfPicker.Close();
            var organizerTask=PdfOrganizer.CreateAsync(window,fixturePdf);var organizerUntil=DateTime.UtcNow.AddSeconds(10);while(!organizerTask.IsCompleted&&DateTime.UtcNow<organizerUntil)DesktopInput.Pump(35);if(!organizerTask.IsCompleted)throw new TimeoutException("Synthetic PDF organizer did not render in time.");var organizer=organizerTask.GetAwaiter().GetResult();organizer.Show();DesktopInput.Pump(180);var pageThumbnail=VisualDescendants(organizer).OfType<System.Windows.Controls.Image>().FirstOrDefault(image=>image.Source is BitmapSource);var thumbnails=pageThumbnail is null?0:1;var colorful=false;if(pageThumbnail?.Source is BitmapSource thumbnail){var thumbnailPixels=new byte[thumbnail.PixelWidth*thumbnail.PixelHeight*4];new FormatConvertedBitmap(thumbnail,PixelFormats.Bgra32,null,0).CopyPixels(thumbnailPixels,thumbnail.PixelWidth*4,0);colorful=Enumerable.Range(0,thumbnailPixels.Length/4).Any(index=>thumbnailPixels[index*4]!=thumbnailPixels[index*4+1]||thumbnailPixels[index*4+1]!=thumbnailPixels[index*4+2]);}var organizerVisual=organizer.Pages.Length==1&&thumbnails==1&&colorful;Check("pdf-organizer-renders-page-thumbnail",organizerVisual,$"pages={organizer.Pages.Length}, thumbnails={thumbnails}, colorful={colorful}");if(organizerVisual)Capture(organizer,Path.Combine(output,"pdf-organizer.png"));organizer.Close();
            Capture(window,Path.Combine(output,"pill-collapsed.png"));

            DesktopInput.MovePointer(window.PointToScreen(new Point(window.ActualWidth/2,window.ActualHeight/2)));
            var hovered=WaitFor(()=>window.UIAuditIslandExpanded,TimeSpan.FromMilliseconds(900));
            Check("hover-expands",hovered&&window.ActualWidth<=PillGeometry.ExpandedWidth+1&&window.ActualHeight<=PillGeometry.ExpandedHeight+1,$"expanded={window.UIAuditIslandExpanded}, size={window.ActualWidth:0}x{window.ActualHeight:0}");
            Capture(window,Path.Combine(output,"pill-expanded-now.png"));

            DesktopInput.MovePointer(new Point(SystemParameters.PrimaryScreenWidth-40,SystemParameters.PrimaryScreenHeight-90));
            var collapsed=WaitFor(()=>!window.UIAuditIslandExpanded,TimeSpan.FromSeconds(1));
            Check("leave-collapses-after-delay",collapsed,"the panel stayed expanded after the pointer left");
            var hidden=WaitFor(()=>!window.IsVisible,TimeSpan.FromSeconds(4));
            Check("auto-hides-after-idle",hidden,"the automatic mode left a persistent pill visible");

            if(!PillVisibilityState.IsSuppressed())
            {
                var hotEdgePoint=window.UIAuditHotEdgePoint;
                DesktopInput.MovePointer(hotEdgePoint);
                var hotEdge=WaitFor(()=>window.IsVisible&&window.UIAuditIslandExpanded,TimeSpan.FromSeconds(1));
                var hit=WindowFromPoint(new NativePoint{X=(int)hotEdgePoint.X,Y=(int)hotEdgePoint.Y});
                GetWindowRect(window.UIAuditHotEdgeHandle,out var edgeBounds);
                Check("hot-edge-reopens",hotEdge,$"visible={window.UIAuditHotEdgeVisible}, point={hotEdgePoint.X:0},{hotEdgePoint.Y:0}, bounds={edgeBounds.Left},{edgeBounds.Top},{edgeBounds.Right},{edgeBounds.Bottom}, hit=0x{hit.ToInt64():X}, edge=0x{window.UIAuditHotEdgeHandle.ToInt64():X}, enter={window.UIAuditHotEdgeEnterCount}");
            }
            else checks.Add(new{name="hot-edge-reopens",passed=(bool?)null,detail="not run: Windows is suppressing interruption surfaces"});

            window.Show();window.UIAuditPresentIsland(true);DesktopInput.Pump(100);
            var before=window.UIAuditHotkeyMessages;SendShortcut(window);
            var shortcutHides=WaitFor(()=>!window.IsVisible,TimeSpan.FromMilliseconds(900));
            Check("registered-shortcut-hides",shortcutHides,$"Ctrl+Alt+N did not hide the panel (WM_HOTKEY messages: {window.UIAuditHotkeyMessages-before}, visible={window.IsVisible}, expanded={window.UIAuditIslandExpanded}, enabled={window.UIAuditPillModeEnabled}, hidden={window.UIAuditHiddenByAutomation})");
            before=window.UIAuditHotkeyMessages;SendShortcut(window);
            var shortcutShows=WaitFor(()=>window.IsVisible&&window.UIAuditIslandExpanded,TimeSpan.FromMilliseconds(900));
            Check("registered-shortcut-shows",shortcutShows,$"Ctrl+Alt+N did not restore the expanded panel (WM_HOTKEY messages: {window.UIAuditHotkeyMessages-before}, visible={window.IsVisible}, expanded={window.UIAuditIslandExpanded}, enabled={window.UIAuditPillModeEnabled}, hidden={window.UIAuditHiddenByAutomation})");
            Capture(window,Path.Combine(output,"pill-hotkey-expanded.png"));

            foreach(var tab in new[]{"now","tray","media","notes","todo","tools"})
            {
                var clicked=window.UIAuditClickDock(tab);
                var targetTab=tab=="tools"?"actions":tab;
                var opened=clicked&&WaitFor(()=>window.UIAuditIslandTab==targetTab,TimeSpan.FromMilliseconds(900));
                Check("dock-opens-"+tab,opened,$"mouse click did not select the {tab} module");
                if(opened)Capture(window,Path.Combine(output,"module-"+tab+".png"));
            }
            foreach(var (action,tab) in new[]{("Open Pocket","pocket"),("Open calendar","calendar"),("Open teleprompter","prompter"),("Open mirror","mirror")})
            {
                var clicked=window.UIAuditClickAction(action);
                var opened=clicked&&WaitFor(()=>window.UIAuditIslandTab==tab,TimeSpan.FromMilliseconds(900));
                Check("search-opens-"+tab,opened,$"mouse selection of {action} did not open {tab}");
                if(opened)Capture(window,Path.Combine(output,"module-"+tab+".png"));
            }
            window.UIAuditClickDock("notes");
            if(window.UIAuditNoteEditor is {} note)
            {
                DesktopInput.Click(note);DesktopInput.TypeText("Synthetic smoke note");DesktopInput.Pump(120);
                var saved=File.Exists(window.UIAuditWidgetStatePath)&&File.ReadAllText(window.UIAuditWidgetStatePath).Contains("Synthetic smoke note",StringComparison.Ordinal);
                Check("notes-save-locally",saved,"typed note was not saved in the isolated Nashi data directory");
                if(saved)Capture(window,Path.Combine(output,"module-notes-filled.png"));
            }
            else Check("notes-save-locally",false,"notes editor did not appear");
            window.UIAuditClickDock("todo");
            if(window.UIAuditTodoEditor is {} todo)
            {
                DesktopInput.Click(todo);DesktopInput.TypeText("Synthetic smoke task");DesktopInput.Key(window,Key.Enter);DesktopInput.Pump(120);
                var saved=File.Exists(window.UIAuditWidgetStatePath)&&File.ReadAllText(window.UIAuditWidgetStatePath).Contains("Synthetic smoke task",StringComparison.Ordinal);
                Check("todo-saves-locally",saved,"typed task was not saved in the isolated Nashi data directory");
                if(saved)Capture(window,Path.Combine(output,"module-todo-filled.png"));
            }
            else Check("todo-saves-locally",false,"to-do entry did not appear");
            Check("search-indexes-note",window.UIAuditActionSearchContains("Synthetic smoke note"),"the local action search did not find the saved note");
            Check("search-indexes-todo",window.UIAuditActionSearchContains("Synthetic smoke task"),"the local action search did not find the saved task");
            Check("search-enter-opens-note",window.UIAuditSubmitActionSearch("Synthetic smoke note","notes"),"Enter did not activate the first matching local search result");
            var timerStarted=window.UIAuditClickAction("Start 25-minute timer")&&WaitFor(()=>window.UIAuditTimerRunning&&window.UIAuditIslandTab=="timer"&&window.IsVisible&&window.UIAuditIslandExpanded,TimeSpan.FromMilliseconds(900));
            Check("timer-starts-from-search",timerStarted,$"running={window.UIAuditTimerRunning}, tab={window.UIAuditIslandTab}, visible={window.IsVisible}, expanded={window.UIAuditIslandExpanded}");
            if(timerStarted)Capture(window,Path.Combine(output,"module-timer.png"));
        }
        finally{if(window.IsVisible)window.Close();}
        File.WriteAllText(Path.Combine(output,"report.json"),JsonSerializer.Serialize(new{checks,failures},new JsonSerializerOptions{WriteIndented=true}));
        Console.WriteLine(JsonSerializer.Serialize(new{checks=checks.Count,failed=failures.Count,output}));
        return failures.Count==0?0:1;
    }

    private static IEnumerable<DependencyObject> VisualDescendants(DependencyObject root)
    {
        for(var index=0;index<VisualTreeHelper.GetChildrenCount(root);index++){var child=VisualTreeHelper.GetChild(root,index);yield return child;foreach(var descendant in VisualDescendants(child))yield return descendant;}
    }
    private static bool WaitFor(Func<bool> condition,TimeSpan timeout)
    {
        var until=DateTime.UtcNow+timeout;while(DateTime.UtcNow<until){DesktopInput.Pump(35);if(condition())return true;}return condition();
    }
    private static void SendShortcut(MainWindow window)
    {
        DesktopInput.Key(window,Key.N,control:true,alt:true);
    }
    private static void Capture(FrameworkElement element,string path)
    {
        element.UpdateLayout();var width=(int)Math.Ceiling(element.ActualWidth);var height=(int)Math.Ceiling(element.ActualHeight);
        if(width<1||height<1)throw new InvalidOperationException("A pill screenshot had an empty layout.");
        var bitmap=new RenderTargetBitmap(width,height,96,96,PixelFormats.Pbgra32);bitmap.Render(element);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));using var stream=File.Create(path);encoder.Save(stream);
    }
}
#endif
