抗锯齿示例程序：

MSAA

FXAANVIDIA 最常用的实现FXAA的方式，直接使用NIVIA的FXAA3.11源码，可用于生产环境。

FXAASelf 自己实现的FXAA代码。

SMAANVIDIA NVIDIA中实现的 SMAA，适合作为生产环境使用。

SMAASelf 自己实现的SMAA，没有使用预计算的方式计算混合系数，而是使用实时计算的混合系数，也没有实现 SMAA 斜向的抗锯齿。

TAASimple 自己实现的简易版TAA。