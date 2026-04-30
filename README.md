主要是3个main file：pass1.m; pass2New.m; pass3Trial;

  pass1：C_1 = L^{-1}(I_e) -- 线性拟合 --> C_s -- Lambert-Beer Law --> I_s --> I_f = I_s*C_s --> corr I_f / I_e --> <corr>

  第一个主要实现：通过16张time averaged，时间顺序的图片，8张top，8张bottom，拟合出函数：f_b(t),g_b(x)和f_t(t), g_t(x)。然后得到I_b(x,t), I_t(x,t)。
  把他们再差值回到对应的frame当中，从底部到顶部线性拟合出整张图C_k。然后C_s = C_1 / C_k，通过Lambert-Beer law 得到一个intensity sheet，然后把C_s的取值拉回到真实的数值。
  从而计算corr = I_f / I_e， 然后取corr的平均。

  pass2：I_e' = <corr> * I_e
  第二个主要是给全部frames乘上这个correction factor。

  pass3: 针对I_e'去除斜影。这里还有 bright Image -- uniform concentration image 和 black image。
  主要运用的是已经写好的L^{-1} := function corr_PLIF_20250906。但是这部分的filter并不是太好，没有解决boundary的问题。
   
这中间有camera space 到 ray space的mapping，然后为了更直观，我会发一些ppt，里面是我的记录，比较乱，但可以看看图片，可能有有用的。
具体尺寸：1024*3320.但是在mapping到ray space做crank-nicolson的时候右边会有数据丢失。这里只能放弃。
由于L^{-1} := function corr_PLIF_20250906, 这个function的边界处理的不好，所以本来对C_1的处理就是四边都截一些。
所以整个步骤目前是有两个地方会产生数据丢失，但后续可以优化L^{-1}，把边界搞好。
