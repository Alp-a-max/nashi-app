using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;

namespace Nashi.Windows;

internal sealed class PillHotEdgeWindow : Window
{
    [StructLayout(LayoutKind.Sequential)] private struct NativePoint { internal int X,Y; }
    [StructLayout(LayoutKind.Sequential)] private struct NativeRect { internal int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out NativePoint point);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd,out NativeRect rect);
    private readonly Window anchor;
    private readonly Action activate;
    private bool armed=true;
    internal int EnterCount{get;private set;}

    internal PillHotEdgeWindow(Window anchor, Action activate)
    {
        this.anchor = anchor;
        this.activate = activate;
        Width = 240;
        Height = 2;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        // The layered window needs non-zero alpha for Windows hit testing.
        // At 1% opacity the 2 px strip remains visually imperceptible.
        Background = System.Windows.Media.Brushes.Black;
        Opacity = .01;
        ShowInTaskbar = false;
        ShowActivated = false;
        Topmost = true;
        ResizeMode = ResizeMode.NoResize;
        Cursor = Cursors.Arrow;
        MouseEnter += (_, _) =>
        {
            EnterCount++;
            if(!armed)return;
            if (PillVisibilityState.IsSuppressed()) return;
            activate();
        };
        MouseLeave += (_,_)=>armed=true;
        Closed += (_, _) => { };
        Position();
    }

    internal void Position()
    {
        var area = DesktopGeometry.WorkArea(anchor);
        Left = area.Left + Math.Max(0, (area.Width - Width) / 2);
        Top = Math.Max(0, area.Top);
    }

    internal void ShowRespectingPointer()
    {
        DisarmIfPointerInside();
        if(!IsVisible)Show();
    }
    internal void DisarmIfPointerInside()
    {
        if(GetCursorPos(out var cursor)&&GetWindowRect(new System.Windows.Interop.WindowInteropHelper(this).Handle,out var bounds)
            &&cursor.X>=bounds.Left&&cursor.X<bounds.Right&&cursor.Y>=bounds.Top&&cursor.Y<bounds.Bottom)armed=false;
    }
}

internal static class PillVisibilityState
{
    [DllImport("shell32.dll", PreserveSig = true)]
    private static extern int SHQueryUserNotificationState(out int state);

    internal static bool IsSuppressed()
    {
        try
        {
            // Only QUNS_ACCEPTS_NOTIFICATIONS (5) is an interruptible desktop state.
            return SHQueryUserNotificationState(out var state) == 0 && state != 5;
        }
        catch (DllNotFoundException) { return false; }
        catch (EntryPointNotFoundException) { return false; }
    }
}
