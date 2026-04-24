local monitor = peripheral.find("monitor")
if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    print("Monitor cleared.")
else
    print("No monitor found.")
end
