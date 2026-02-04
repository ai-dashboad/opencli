# Flutter Skill 真机自动化测试计划

## 测试方式

使用Flutter Skill MCP工具连接到运行在真机/模拟器上的Flutter应用，执行真实的UI自动化测试。

## 测试步骤

### 1. 连接到应用

```
使用 mcp__flutter-skill__launch_app 或 mcp__flutter-skill__connect_app
连接到运行中的Flutter应用VM Service
```

### 2. Android应用测试清单

#### A. 连接验证
- [ ] 检查应用启动状态
- [ ] 获取widget树结构
- [ ] 验证daemon连接状态显示

#### B. UI元素检查
- [ ] 使用 `inspect` 获取所有可交互元素
- [ ] 验证输入框存在
- [ ] 验证发送按钮存在
- [ ] 验证导航栏存在

#### C. 消息发送测试
- [ ] 使用 `tap` 点击输入框
- [ ] 使用 `enter_text` 输入 "Hello from automated test"
- [ ] 使用 `tap` 点击发送按钮
- [ ] 使用 `get_text_content` 验证消息显示
- [ ] 等待并验证收到AI响应

#### D. 导航测试
- [ ] 使用 `tap` 点击底部导航项
- [ ] 验证页面切换
- [ ] 使用 `go_back` 测试返回功能

#### E. 任务功能测试
- [ ] 点击创建任务按钮
- [ ] 输入任务信息
- [ ] 提交任务
- [ ] 验证任务状态更新

### 3. iOS应用测试清单

（与Android相同的测试项）

### 4. macOS Menubar测试

macOS Menubar应用使用系统托盘，Flutter Skill可能无法直接测试菜单项。
需要手动测试或使用AppleScript。

### 5. WebUI测试

WebUI不是Flutter应用，需要使用Puppeteer/Playwright测试。

## Flutter Skill MCP工具

可用的工具：

### 应用连接
- `connect_app(uri)` - 连接到VM Service
- `launch_app(project_path, device_id)` - 启动应用并自动连接

### UI检查
- `inspect()` - 获取可交互元素列表
- `get_widget_tree(max_depth)` - 获取widget树
- `get_text_content()` - 获取所有文本内容
- `find_by_type(type)` - 查找特定类型的widget

### UI交互
- `tap(key/text)` - 点击元素
- `enter_text(key, text)` - 输入文字
- `long_press(key/text)` - 长按
- `double_tap(key/text)` - 双击
- `swipe(direction, distance)` - 滑动
- `drag(from_key, to_key)` - 拖拽

### 状态查询
- `get_text_value(key)` - 获取文本框内容
- `get_checkbox_state(key)` - 获取checkbox状态
- `get_slider_value(key)` - 获取slider值

### 导航
- `get_current_route()` - 获取当前路由
- `go_back()` - 返回
- `get_navigation_stack()` - 获取导航栈

### 调试
- `screenshot()` - 截图
- `get_logs()` - 获取日志
- `get_errors()` - 获取错误
- `get_performance()` - 获取性能指标
- `hot_reload()` - 热重载

## 预期结果

所有测试应该能够：
1. 成功连接到真机/模拟器上的应用
2. 检测到所有必需的UI元素
3. 成功执行点击、输入等操作
4. 验证操作后的状态变化
5. 截图记录测试过程

## 优势

相比手动测试：
- ✅ 自动化执行，可重复
- ✅ 在真实设备上运行
- ✅ 真实的UI交互（不是mock）
- ✅ 可以截图记录
- ✅ 可以获取性能数据

相比integration_test：
- ✅ 可以连接到已运行的应用
- ✅ 不需要重新编译
- ✅ 可以实时检查和调试
- ✅ 更灵活的测试脚本
