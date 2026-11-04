import math

R, C, V0 = 10e3, 100e-6, 5.0       # ohms, farads, volts
tau = R * C                         # time constant, seconds
for t in (0.0, 0.5, 1.0, 2.0, 3.0):
    v = V0 * math.exp(-t / tau)
    print(f"t = {t:3.1f} s   v = {v:4.2f} V")
print(f"half-life = {tau * math.log(2):.3f} s")
