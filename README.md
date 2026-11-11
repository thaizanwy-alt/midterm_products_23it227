# Kho sản phẩm Flutter

Bài kiểm tra giữa kỳ cá nhân môn Lập trình đa nền tảng của **Thái Văn Quý** (23IT227, 23SE2). Project được tạo ngày 11/11/2026 cho Flutter Web và Android. Hai nền tảng dùng chung Cloud Firestore và Firebase Authentication.

## Chạy project

Cần Flutter 3.41.6 (Dart 3.11.4), Chrome, Android SDK và JDK 17. Android tối thiểu API 24. Với PowerShell trên máy đã cài JDK tại `D:\jdk-17.0.12`, đặt đường dẫn cho phiên hiện tại trước khi chạy Android.

```powershell
$env:JAVA_HOME = 'D:\jdk-17.0.12'
flutter doctor -v
flutter pub get
flutter analyze
flutter devices
flutter run -d chrome --web-port=8080
```

Mở LDPlayer9 hoặc thiết bị Android đã bật gỡ lỗi USB. Với LDPlayer9 trên máy kiểm thử, cổng ADB là `5555`. Dùng ID thực tế từ `flutter devices` nếu cổng khác.

```powershell
adb connect 127.0.0.1:5555
adb devices -l
flutter run -d 127.0.0.1:5555
```

Đăng nhập bằng tài khoản admin được cấp riêng. Mật khẩu lưu ngoài repo. Trong project đã có cấu hình ứng dụng Firebase cho `thaivanquy-23it227-firebase`. Firebase SDK dùng thông tin đăng ký này, còn Firestore Rules quyết định quyền đọc và ghi.

## Cấu hình Firebase khi làm lại

1. Trong Firebase Console, tạo hoặc chọn dự án. Mở **Firestore Database → Create database**, chọn **Standard**, database `(default)`, vùng phù hợp và chế độ khóa mặc định. Bản demo dùng `asia-southeast1`.
2. Mở **Authentication → Get started → Sign-in method → Email/Password**, bật **Email/Password** và **Save**. Trong **Users → Add user**, tạo tài khoản admin, sau đó sao chép **User UID**.
3. Thay UID trong `firestore.rules` và giá trị mặc định `AuthService.adminUid` trong `lib/services/auth_service.dart`. Dùng cùng một UID ở hai nơi. Chạy lệnh sau với Project ID của bạn. FlutterFire đăng ký ứng dụng theo package ID Android `vn.edu.vku.midterm_products_23it227`.

```powershell
firebase.cmd login
dart pub global activate flutterfire_cli
dart pub global run flutterfire_cli:flutterfire configure --project=thaivanquy-23it227-firebase --platforms=web,android --android-package-name=vn.edu.vku.midterm_products_23it227 --yes
firebase.cmd deploy --only firestore --project thaivanquy-23it227-firebase
```

`firestore.rules` xác thực UID admin và kiểm tra đủ bốn trường đúng kiểu khi ghi. `firestore.indexes.json` bỏ chỉ mục của `image`, trường chỉ dùng để hiển thị. Danh sách lắng nghe `products` theo `name`.

## Cấu trúc dữ liệu

Mỗi document ở `products/<Document ID>` có bốn trường:

| Trường | Kiểu Firestore | Giá trị |
| --- | --- | --- |
| `name` | string | Tên sản phẩm, tối đa 100 ký tự |
| `price` | number | Giá bằng đồng, chấp nhận số nguyên và tối đa hai chữ số thập phân từ form |
| `soluong` | integer | Số lượng từ 0 đến 2147483647 |
| `image` | string | Base64 của ảnh JPEG hoặc PNG đã xử lý |

Firestore sinh Document ID khi thêm. Ứng dụng dùng ID này để sửa và xóa. Ảnh đầu vào tối đa 10 MiB và 16 megapixel. Ứng dụng thu cạnh dài về tối đa 960 px và kiểm tra ảnh sau xử lý tối đa 256 KiB, tương đương 349528 ký tự Base64.

## Tìm code theo chức năng

| Thao tác | File và hàm |
| --- | --- |
| Khởi tạo Firebase Web và Android | `lib/main.dart` → `main()`, `lib/firebase_options.dart` → `DefaultFirebaseOptions.currentPlatform` |
| Điều hướng theo phiên admin | `lib/main.dart` → `_AuthGateState.build()` |
| Đăng nhập, đăng xuất và kiểm tra UID | `lib/services/auth_service.dart` → `signIn()`, `signOut()`, `isAdmin()` |
| Đọc và ghi đúng bốn trường | `lib/models/product.dart` → `Product.fromFirestore()`, `toFirestore()` |
| Xem danh sách thời gian thực | `lib/services/product_service.dart` → `watchProducts()` |
| Thêm, sửa, xóa đúng document | `lib/services/product_service.dart` → `add()`, `update()`, `delete()` |
| Xác nhận xóa và hiển thị danh sách | `lib/screens/product_list_screen.dart` → `_delete()`, `_row()` |
| Chọn ảnh và thu nhỏ | `lib/screens/product_form_screen.dart` → `_pickImage()`, `_encodePhoto()` |
| Kiểm tra và lưu form chung | `lib/screens/product_form_screen.dart` → `_parsePrice()`, `_parseQuantity()`, `_save()` |
| Giải mã và hiển thị ảnh | `lib/widgets/product_image.dart` → `ProductImage.build()` |

## Kịch bản kiểm thử và quay demo

1. Trên Chrome, thử mật khẩu sai để thấy thông báo, sau đó đăng nhập admin. Giữ mật khẩu ở chế độ ẩn khi ghi hình.
2. Thêm một sản phẩm có ảnh, tên, giá và số lượng. Quay ảnh xem trước và dòng vừa lưu. Tải lại URL ở cùng cổng và kiểm tra dòng vẫn hiển thị.
3. Sửa giá hoặc số lượng. Tạo thêm một sản phẩm tạm để minh họa xóa rồi xác nhận. Giữ lại sản phẩm chính để xuất JSON.
4. Trên Android, vào **Thêm sản phẩm → Chọn ảnh**, chọn JPEG/PNG từ thiết bị, điền thông tin và lưu. Đóng rồi mở lại app để thấy ảnh và thông tin. Kiểm tra chính sản phẩm Android xuất hiện trên Web.
5. Mở Firebase Console, vào **Firestore Database → Data**, chọn collection `products` và mở một document để thấy bốn trường. Tiếp tục chạy Query builder và xuất JSON như bên dưới.
6. Nếu quay bằng OBS, ghi cửa sổ Chrome và LDPlayer9 theo thứ tự trên. Tải MP4 lên Google Drive. Mở **Chia sẻ**, cấp quyền xem cho người chấm hoặc chọn **Bất kỳ ai có đường liên kết → Người xem** theo yêu cầu nộp bài. Sao chép link và kiểm tra bằng tài khoản có quyền trước khi dán vào Word.

Để xác minh quyền, đăng xuất và kiểm tra ứng dụng trở về màn hình đăng nhập. Trong **Firestore Database → Rules → Rules playground**, dùng đường dẫn `/products/<Document ID thật>` và chọn truy cập chưa xác thực. Thử `get`, sau đó thử `create` bằng dữ liệu hợp lệ và đối chiếu cả hai đều bị từ chối. Có thể thử lại với UID khác và với UID admin để đối chiếu quyền.

## Xuất JSON bằng Firexport

1. Cài [Firexport từ Chrome Web Store](https://chromewebstore.google.com/detail/firexport-firestore-expor/jffbbophhgjoholadeeehbkecddgajhc). Mở lại hoặc tải lại trang Firebase Console.
2. Mở **thaivanquy-23it227-firebase → Firestore Database → Data → Query builder**.
3. Chọn **Query scope → Collection**, nhập **Path** là `/products`, để trống bộ lọc và đặt **Limit** lớn hơn hoặc bằng số sản phẩm demo. Bấm **Run**.
4. Trong **Results**, bấm **⋮** cạnh **Export → Export to JSON**. Đổi tên tệp tải về thành `23IT227_Products.json` và chép vào `submission/`.
5. Mở tệp trong VS Code và kiểm tra số bản ghi khớp Results. Giữ Document ID ở phần định danh nếu Firexport có xuất kèm. Dữ liệu sản phẩm có `name` và `image` dạng chuỗi, `price` dạng số, `soluong` dạng số nguyên. Đối chiếu ảnh Base64 đầy đủ với giá trị Firestore hoặc giải mã lại để xác minh ảnh mở được.

### Ảnh minh chứng cần lưu trong `docs/screenshots/`

| Tệp | Vùng cần thấy |
| --- | --- |
| `01-flutter-doctor.png` | Phiên bản Flutter, Android toolchain, Chrome và LDPlayer9 |
| `02-web-form.png` | Form Web có ba giá trị đã nhập và ảnh xem trước |
| `03-web-reload.png` | Chrome sau tải lại, sản phẩm có ảnh, giá và số lượng |
| `04-login-error.png` | Thông báo sai mật khẩu, trường mật khẩu được che |
| `05-web-edit.png` | Dòng sản phẩm có giá hoặc số lượng sau sửa |
| `06-web-delete.png` | Danh sách sau xóa và thông báo xác nhận |
| `07-android-picker.png` | Trình chọn ảnh trên LDPlayer9 |
| `08-android-reopen.png` | App Android sau mở lại, có ảnh và thông tin sản phẩm vừa lưu |
| `09-firestore-document.png` | Document ID và đủ bốn trường trong Firebase Console |
| `10-firexport-query.png` | Collection `/products`, Limit, Results và nút Export |
| `11-firexport-json.png` | Tệp `23IT227_Products.json` mở trong trình soạn thảo với tên tệp và bốn trường |

Tài liệu chính thức để đối chiếu: [FlutterFire setup](https://firebase.google.com/docs/flutter/setup), [Firestore Rules theo trường](https://firebase.google.com/docs/firestore/security/rules-fields), [Firexport](https://firexport.dev/).
