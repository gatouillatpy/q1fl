Here is my port of GLQuake for Molehill (aka Stage3D), based on Michael Rennie's port of Quake for Flash, using Alchemy.

Basically in the original port the idea was just to leave Carmack's engine do its job in C and then copy the resulting frame buffer from the Alchemy memory to a displayed Bitmap. However for GLQuake the approach is different because we have to replace all OpenGL calls by Molehill equivalents.

During one frame there can be at least 10 thousand GL calls and there is a problem with that because we can't directly access Bitmap3D features from C code, and there is a huge function-call overhead between C code and Flash objects.

Consequently I had to transform every OpenGL call into pseudo instructions stored in memory, then finally flush everything in a single call. But that wasn't enough because it's still too heavy for each glBegin/glEnd to do a vertex/index buffer upload and then draw. The solution is to manually check and draw only when a state changes, like when there is a call to glOrtho, glBind, glBlendFunc.

In the end it's working but that's clearly not a good benchmark because there are too many things in GLQuake tied with the legacy software engine. For example lightmapping and animated textures are rebuilt in software, that could be done with a pixel shader. Moreover mesh animations and shadows are calculated in software as well. In GLQuake the hardware is just used for the final rendering, so that port isn't really taking advantage of Molehill. Maybe a Quake3 port would be more representative as it uses vertex buffers, shaders...

Here are my results:

Benchmark configuration :
Intel Core i3 330M
4 GBytes DDR3
GeForce GT 330M
Windows 7 (64 bits)

Original port using software rasterizer:
TIMEDEMO DEMO1
969 FRAMES / 30.1 SECONDS / 32.1 FPS

New port using hardware capabilities:
TIMEDEMO DEMO1
969 FRAMES / 31.9 SECONDS / 30.4 FPS

Original WinQuake:
TIMEDEMO DEMO1
969 FRAMES / 20.2 SECONDS / 48.0 FPS

Original GLQuake: not working

Original D3DQuake: 
TIMEDEMO DEMO1
969 FRAMES / 9.7 SECONDS / 99.9 FPS

Benchmark configuration:
Intel Xeon X3520
6 GBytes DDR3
GeForce GTX 260
Windows XP SP3 (32 bits)

Original port using software rasterizer:
TIMEDEMO DEMO1
969 FRAMES / 22.7 SECONDS / 42.7 FPS

New port using hardware capabilities:
TIMEDEMO DEMO1
969 FRAMES / 27.5 SECONDS / 35.2 FPS