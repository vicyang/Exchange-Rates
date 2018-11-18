### 获取外汇牌价历史记录 、数据可视化  
  
* ### 环境配置  
  推荐 Strawberry Perl Portable PDL Edition  
  在 Strawberry Perl 的基础上需要添加的模块  
  
    Font::FreeType  
    HTML::TableExtract  
    Math::Geometry::Delaunay  
  
* ### 分支  
  * Branch Visualization  
    基于 tag threads1.0  
  
* ### 目录结构  
  /Data          抓取汇率数据的脚本  
  /Visualization 可视化程序  
  
  * display_control.pl  
    从 ../Data 目录获取数据并展示线条图  
  
    ![](./Visualization/snap02.png)  
  
  * display_triangulation.pl  
    从 ../Data 目录获取数据并展示立体图  
  
    ![](./Visualization/snap01.png)  
  
  * display_nearly.pl  
    展示最近N天的汇率曲线，在线获取数据，不依赖于本地数据。  
    日期设置：  
    `our $from = DateTime->today()->add( days => -5 );`  
  
* BUG  
  2007年8月15日出现最小值为0.076的情况，原因：  
  ```perl
  '2007.08.15' => {
    '16:29:01' => ['7.57','7.51','7.6',undef,'759.21','759.21'],
  }
  ```  
