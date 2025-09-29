# Flutter 房间邀请码校验方案

## 需求背景
- 移动端原本在房间卡片上输入邀请码后，直接跳转至本地模拟的直播间界面，未与后端进行任何校验。
- 后端（ht.pge006.com）已经实现与 meet2 Web 前端一致的接口流程：登录成功或游客身份确认后，需要携带 `room_id`、`invite_code` 和 `user_jwt_token` 调用 `/api/v1/rooms/detail` 获取真实房间信息与 LiveKit Token。
- 业务希望 Flutter 端沿用 meet2 的逻辑，实现“会员模式（已登录用户）”与“游客模式（未登录用户）”两种路径，确保只有邀请码校验通过后才允许进入直播间。

## 方案概述
1. **共用网关接口**
   - `GatewayApiService` 新增 `getAuthStatus` / `fetchRoomDetail` / `joinRoom`，并解析网关返回的认证状态与房间详情，输出给客户端使用。
2. **统一房间数据模型**
   - 新增 `RoomJoinData`，封装房间 ID、房间名、邀请码、LiveKit Token、WS 地址以及附加的房间/用户信息，便于界面和后续逻辑复用。
3. **邀请码验证流程**
   - 点击房间卡片弹出的邀请码面板中，`_verifyInviteCode()` 会根据登录状态走不同分支：
     - **会员模式**：读取本地登录态的用户名、JWT，直接调用 `joinRoom` 校验邀请码并获取房间详情。
     - **游客模式**：先请求 `getAuthStatus()` 获取访客身份及 Token，再携带邀请码调用 `joinRoom`。
   - 校验失败时提示错误，成功后构造 `RoomJoinData` 并关闭面板。
4. **直播间界面接入真实数据**
   - `VideoConferenceScreen` 改为接收 `RoomJoinData`，在 `_initializeData()` 中根据返回的房间信息初始化主持人、麦位等展示内容；后续接入 LiveKit 时可直接使用同一结构。
5. **体验优化**
   - 增加 `_isInviteSubmitting`，在邀请码请求过程中禁用按钮并展示菊花，防止重复提交。

## 关键改动
- `lib/services/gateway_api_service.dart`：新增房间详情/认证数据结构及接口封装。
- `lib/screens/meet_list_screen.dart`：改写邀请码验证逻辑，区分登录与游客流程，构造房间 Join Data。
- `lib/models/room_join_data.dart`：定义房间 + LiveKit 会话数据模型。
- `lib/screens/video_conference_screen.dart`：改用 `RoomJoinData` 初始化界面内容，为后续接入真实 LiveKit 铺路。

## 后续可扩展点
- 将 `RoomJoinData` 缓存到状态管理（Provider/Bloc）以支持断线重连或多页面共享。
- 在 `VideoConferenceScreen` 中替换当前视频播放器实现，接入 LiveKit SDK 播放真实房间流。
- 结合网关的刷新接口，实现 Access/Refresh Token 到期自动续订。
