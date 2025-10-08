import pandas as pd
import matplotlib.pyplot as plt

# Load the data
file_path = "LOG_FILES/DATA/big_log_lab_data.csv"
data = pd.read_csv(file_path, parse_dates=["Time"])

# Drop rows with all NaN values
data.dropna(how="all", inplace=True)

# Plot Currents and HVs
fig, ax1 = plt.subplots(figsize=(10, 6))
ax2 = ax1.twinx()

currents = ["hv4_CurrentNeg", "hv4_CurrentPos", "hv5_CurrentNeg", "hv5_CurrentPos"]
hvs = ["hv4_HVneg", "hv4_HVpos", "hv5_HVneg", "hv5_HVpos"]

for col in currents:
    if col in data:
        ax1.plot(data["Time"], data[col], label=col)

for col in hvs:
    if col in data:
        ax2.plot(data["Time"], data[col], linestyle="--", label=col)

ax1.set_ylabel("Currents")
ax2.set_ylabel("HVs")
ax1.set_xlabel("Time")
ax1.legend(loc="upper left")
ax2.legend(loc="upper right")
plt.title("Currents and HVs")
plt.show()

# Plot Rates (Asserted, Edge, Accepted)
fig, ax = plt.subplots(figsize=(10, 6))
rates = ["rates_Asserted", "rates_Edge", "rates_Accepted"]

for col in rates:
    if col in data:
        ax.plot(data["Time"], data[col], label=col)

ax.set_ylabel("Rates")
ax.set_xlabel("Time")
ax.legend()
plt.title("Rates (Asserted, Edge, Accepted)")
plt.show()

# Plot Rates Multiplexer and CM
fig, ax1 = plt.subplots(figsize=(10, 6))
ax2 = ax1.twinx()

multiplexer = [f"rates_Multiplexer{i}" for i in range(1, 13)]
cm = [f"rates_CM{i}" for i in range(1, 13)]

for col in multiplexer:
    if col in data:
        ax1.plot(data["Time"], data[col], label=col)

for col in cm:
    if col in data:
        ax2.plot(data["Time"], data[col], linestyle="--", label=col)

ax1.set_ylabel("Rates Multiplexer")
ax2.set_ylabel("Rates CM")
ax1.set_xlabel("Time")
ax1.legend(loc="upper left")
ax2.legend(loc="upper right")
plt.title("Rates Multiplexer and CM")
plt.show()

# Plot Sensors
fig, axes = plt.subplots(3, 1, figsize=(10, 12), sharex=True)
sensors = ["sensors_Temperature_ext", "sensors_RH_ext", "sensors_Pressure_ext"]

for ax, col in zip(axes, sensors):
    if col in data:
        ax.plot(data["Time"], data[col], label=col)
        ax.set_ylabel(col)
        ax.legend()

axes[-1].set_xlabel("Time")
plt.suptitle("Sensors")
plt.show()