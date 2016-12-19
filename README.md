iOS-cluster-marker
========================

MAMapKit 点聚合

### 前述

- [高德官方网站申请key](http://id.amap.com/?ref=http%3A%2F%2Fapi.amap.com%2Fkey%2F).
- 阅读[参考手册](http://api.amap.com/Public/reference/iOS%20API%20v2_3D/).
- 工程基于iOS 3D地图SDK实现

### 核心类/接口
| 类    | 接口  | 说明   | 版本  |
| -----|:-----:|:-----:|:-----:|
| AnnotationClusterViewController | - (void)searchPoiWithKeyword:(NSString *)keyword; | 根据关键字搜索poi点 | n/a |
| CoordinateQuadTree | - (void)buildTreeWithPOIs:(NSArray *)pois; | 根据返回poi建树 | n/a |
| AnnotationClusterViewController | - (void)addAnnotationsToMapView:(MAMapView *)mapView; | 把annotation添加到地图 | n/a |
| AnnotationClusterViewController | - (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated; | 响应地图区域变化回调，刷新annotations | n/a |

### 使用教程

- 调用ClusterAnnotation文件夹下的代码能够实现poi点聚合，使用步骤如下：
- 初始化coordinateQuadTree。
```objc
self.coordinateQuadTree = [[CoordinateQuadTree alloc] init];
```
- 获得poi数组pois后，创建coordinateQuadTree。
 * 项目Demo通过关键字搜索获得poi数组数据，具体见工程。此处从获得poi数组开始说明。
 * 创建四叉树coordinateQuadTree来建立poi的四叉树索引。
 * 创建过程较为费时，建议另开线程。创建四叉树完成后，计算当前mapView下需要显示的annotation。

`Objective-C`
```objc
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    /* 建立四叉树. */
    [self.coordinateQuadTree buildTreeWithPOIs:respons.pois];
        
    dispatch_async(dispatch_get_main_queue(), ^{
            /* 计算当前mapView区域内需要显示的annotation. */
            NSLog(@"First time calculate annotations.");
            [self addAnnotationsToMapView:self.mapView];
    });
});
```

`Swift`
```
DispatchQueue.global(qos: .default).async(execute: { [weak self] in
                
                self?.coordinateQuadTree.build(withPOIs: response.pois)
                self?.shouldRegionChangeReCalculate = true
                self?.addAnnotations(toMapView: (self?.mapView)!)
            })
```

- 根据CoordinateQuadTree四叉树索引，计算当前zoomLevel下，mapView区域内的annotation。

`Objective-C`
```objc
- (void)addAnnotationsToMapView:(MAMapView *)mapView
{
    /* 判断是否已建树. */
    if (self.coordinateQuadTree.root == nil)
    {
        return;
    }
    /* 根据当前zoomLevel和zoomScale 进行annotation聚合. */
    double zoomScale = self.mapView.bounds.size.width / self.mapView.visibleMapRect.size.width;
    /* 基于先前建立的四叉树索引，计算当前需要显示的annotations. */
    NSArray *annotations = [self.coordinateQuadTree clusteredAnnotationsWithinMapRect:mapView.visibleMapRect
                                withZoomScale:zoomScale
                                 andZoomLevel:mapView.zoomLevel];
   
    /* 更新annotations. */
    [self updateMapViewAnnotationsWithAnnotations:annotations];
}
```
`Swift`
```
func addAnnotations(toMapView mapView: MAMapView) {
        synchronized(lock: self) { [weak self] in
            
            guard (self?.coordinateQuadTree.root != nil) || self?.shouldRegionChangeReCalculate != false else {
                NSLog("tree is not ready.")
                return
            }
            
            guard let aMapView = self?.mapView else {
                return
            }
            
            let visibleRect = aMapView.visibleMapRect
            let zoomScale = Double(aMapView.bounds.size.width) / visibleRect.size.width
            let zoomLevel = Double(aMapView.zoomLevel)
            
            DispatchQueue.global(qos: .default).async(execute: { [weak self] in
                
                let annotations = self?.coordinateQuadTree.clusteredAnnotations(within: visibleRect, withZoomScale: zoomScale, andZoomLevel: zoomLevel)
                
                self?.updateMapViewAnnotations(annotations: annotations as! Array<ClusterAnnotation>)
            })
        }
    }
```

- 更新annotations。对比mapView里已有的annotations，吐故纳新。

`Objective-C`
```objc
/* 更新annotation. */
- (void)updateMapViewAnnotationsWithAnnotations:(NSArray *)annotations
{
    /* 用户滑动时，保留仍然可用的标注，去除屏幕外标注，添加新增区域的标注 */
    NSMutableSet *before = [NSMutableSet setWithArray:self.mapView.annotations];
    [before removeObject:[self.mapView userLocation]];
    NSSet *after = [NSSet setWithArray:annotations];
    
    /* 保留仍然位于屏幕内的annotation. */
    NSMutableSet *toKeep = [NSMutableSet setWithSet:before];
    [toKeep intersectSet:after];
    
    /* 需要添加的annotation. */
    NSMutableSet *toAdd = [NSMutableSet setWithSet:after];
    [toAdd minusSet:toKeep];
    
    /* 删除位于屏幕外的annotation. */
    NSMutableSet *toRemove = [NSMutableSet setWithSet:before];
    [toRemove minusSet:after];
    
    /* 更新. */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mapView addAnnotations:[toAdd allObjects]];
        [self.mapView removeAnnotations:[toRemove allObjects]];
    });
}
```
`Swift`
```
func updateMapViewAnnotations(annotations: Array<ClusterAnnotation>) {
        
        /* 用户滑动时，保留仍然可用的标注，去除屏幕外标注，添加新增区域的标注 */
        let before = NSMutableSet(array: mapView.annotations)
        before.remove(mapView.userLocation)
        let after: Set<NSObject> = NSSet(array: annotations) as Set<NSObject>
        
        /* 保留仍然位于屏幕内的annotation. */
        var toKeep: Set<NSObject> = NSMutableSet(set: before) as Set<NSObject>
        toKeep = toKeep.intersection(after)
        
        /* 需要添加的annotation. */
        let toAdd = NSMutableSet(set: after)
        toAdd.minus(toKeep)
        
        /* 删除位于屏幕外的annotation. */
        let toRemove = NSMutableSet(set: before)
        toRemove.minus(after)
        
        DispatchQueue.main.async(execute: { [weak self] () -> Void in
            self?.mapView.addAnnotations(toAdd.allObjects)
            self?.mapView.removeAnnotations(toRemove.allObjects)
        })
    }
```

### 架构

##### Controllers
- `<UIViewController>`
  * `AnnotationClusterViewController` poi点聚合
  * `PoiDetailViewController` 显示poi详细信息列表

##### View

* `MAAnnotationView`
  - `ClusterAnnotationView` 自定义的聚合annotationView

##### Models

* `Conform to <MAAnnotation>`
  - `ClusterAnnotation` 记录annotation的信息，如其代表的poi数组、poi的个数、poi平均坐标，并提供两个annotation是否Equal的判断
* `CoordinateQuadTree` 封装的四叉树类
* `QuadTree` 四叉树基本算法

### 截图效果

![ClusterAnnotation2](https://raw.githubusercontent.com/cysgit/iOS_3D_ClusterAnnotation/master/iOS_3D_ClusterAnnotation/Resources/ClusterAnnotation2.png)
![ClusterAnnotation1](https://raw.githubusercontent.com/cysgit/iOS_3D_ClusterAnnotation/master/iOS_3D_ClusterAnnotation/Resources/ClusterAnnotation1.png)
