本示例程序包含了六个示例场景：

MSAA Unity自带的MSAA。

FXAANVIDIA 最常用的实现FXAA的方式，直接使用NIVIA的FXAA3.11源码，可用于生产环境。

FXAASelf 作者自己实现的FXAA代码，代码结构比较清晰，用于对照文章进行学习。

SMAANVIDIA 是NVIDIA中实现的 SMAA，适合作为生产环境使用。

SMAASelf 是作者自己实现的SMAA，没有使用预计算的方式计算混合系数，而是使用实时计算的混合系数，适合读者对照文章学习用。作者没有实现 SMAA 斜向的抗锯齿，读者可自行添加实现。不过要注意，为了保证和原版的 SMAA 一致，这里没有根据Unity的Opengl方式将UV进行上下调换，不过最终效果都是一样的。

TAASimple 是作者自己实现的TAA，用于说明TAA的实现原理和大致流程(运行起来才能看到实际效果)。想要进一步学习的读者可自行阅读HDRP和UE4中的相关源码。