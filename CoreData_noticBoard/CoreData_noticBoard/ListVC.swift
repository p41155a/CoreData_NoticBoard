//
//  ListVC.swift
//  CoreData_noticBoard
//
//  Created by MC975-107 on 22/09/2019.
//  Copyright © 2019 comso. All rights reserved.
//

import UIKit
import CoreData

class ListVC: UITableViewController {
    
    // 데이터 소스 역활을 할 배열 변수
    lazy var list: [NSManagedObject] = {
        return self.fetch()
    }()
    
    func fetch() -> [NSManagedObject] {
        // 앱 델리게이트 객체 참조
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        // 관리 객체 컴텍스트 참조
        let context = appDelegate.persistentContainer.viewContext
        // 요청 객체 생성
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Board")
        // 정렬 속성 설정
        let sort = NSSortDescriptor(key: "regdate", ascending: false)
        fetchRequest.sortDescriptors = [sort]
        // 데이터 가져오기
        let result = try! context.fetch(fetchRequest)
        return result
    }
    
    //데이터를 저장할 메소드
    func save(title: String, contents: String) -> Bool {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        // 관리 객체 생성 & 값을 설정
        let object = NSEntityDescription.insertNewObject(forEntityName: "Board", into: context)
        object.setValue(title, forKey: "title")
        object.setValue(contents, forKey: "contents")
        object.setValue(Date(), forKey: "regdate")
        // Log 관리 객체 생성 및 어트리뷰트에 값 대입
        let logObject = NSEntityDescription.insertNewObject(forEntityName: "Log", into: context) as! LogMO
        logObject.regdate = Date()
        logObject.type = LogType.create.rawValue // .rawValue속성을 이용하여 Int16 타입의 내부값을 대신 대입
        // 게시글 객체의 logs 속성에 새로 생성된 로그 객체 추가
        (object as! BoardMO).addToLogs(logObject)
        // 영구 저장소에 커밋되고 나면 list 프로퍼티에 추가한다.
        do {
            try context.save()
            // self.list.append(object) // append 메소드를 사용하면 해당 데이터는 항상 배열의 제일 뒤쪽에 추가되기 때문에
            self.list.insert(object, at: 0) //insert(_:at:)메소드를 사용해서 배열 가장 위쪽에 삽입하여 최신글이 먼저 오게함
            return true
        } catch {
            context.rollback()
            return false
        }
    }
    
    //데이터 저장 버튼에 대한 액션 메소드
    @objc func add(_ sender: Any) {
        let alert = UIAlertController(title: "게시글 등록", message: nil, preferredStyle: .alert)
        // 입력 필드 추가(이름 & 전화번호)
        alert.addTextField(){ $0.placeholder = "제목"}
        alert.addTextField(){ $0.placeholder = "내용"}
        // 버튼 추가
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) {(_) in
            guard let title = alert.textFields?.first?.text, let contents = alert.textFields?.last?.text else {
                return
            }
            // 값을 저장, 성공이면 테이블 리로드
            if self.save(title: title, contents: contents) == true {
                self.tableView.reloadData()
            }
        })
        self.present(alert, animated: false)
    }
    
    func delete(object: NSManagedObject) -> Bool {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        context.delete(object)
        // 영구 저장소에 커밋
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            return false
        }
    }
    
    func edit(object: NSManagedObject, title: String, contents: String) -> Bool {
        // 앱 델리게이트 객체 참조
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        // 관리 객체 컨텍스트 참조
        let context = appDelegate.persistentContainer.viewContext
        // 관리 객체의 값을 수정
        object.setValue(title, forKey: "title")
        object.setValue(contents, forKey: "contents")
        object.setValue(Date(), forKey: "regdate")
        // Log관리 객체 생성 및 어트리뷰트에 값 대입
        let logObject = NSEntityDescription.insertNewObject(forEntityName: "Log", into: context) as! LogMO
        logObject.regdate = Date()
        logObject.type = LogType.edit.rawValue
        // 게시글 객체의 logs 속성에 새로 생성된 로그 객체 추가
        (object as! BoardMO).addToLogs(logObject)
        // 영구 저장소에 커밋
        do {
            try context.save()
            self.list = self.fetch() // 글을 수정하면 등록 날짜도 함께 갱신되기 때문에 list 배열을 갱신한다.
            return true
        } catch {
            context.rollback()
            return false
        }
    }

    override func viewDidLoad() {
        let addBtn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add(_:)))
        self.navigationItem.rightBarButtonItem = addBtn
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.list.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 해당하는 데이터 가져오기
        let record = self.list[indexPath.row]
        let title = record.value(forKey: "title") as? String
        let contents = record.value(forKey: "contents") as? String
        // 셀을 생성하고, 값을 대입한다.
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) // 큐에서 자료 꺼냄
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = contents
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let object = self.list[indexPath.row] // 삭제할 대상객체
        if self.delete(object: object) {
            // 코어 데이터에서 삭제되면 배열 목록과 테이블 뷰의 행도 삭제
            self.list.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 선택된 행에 해당하는 데이터 가져옴
        let object = self.list[indexPath.row]
        let title = object.value(forKey: "title") as? String
        let contents = object.value(forKey: "contents") as? String
        
        let alert = UIAlertController(title: "게시글 수정", message: nil, preferredStyle: .alert)
        alert.addTextField() { $0.text = title }
        alert.addTextField() { $0.text = contents }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { (_) in
            guard let title = alert.textFields?.first?.text, let contents = alert.textFields?.last?.text else {
                return
            }
            // 값을 수정하는 메서드 호출, 성공시 테이블 뷰 리로드
            if self.edit(object: object, title: title, contents: contents) == true {
                self.tableView.reloadData()
                // 수정시에 최신을을 제일 위로 올리는 과정시에 위의 소스를 지우고 아래 소스를 쓰라고 나옴
                // 하지만 두 이미 list 를 갱신했는데 왜 또 첫 행으로 이동 시키는지 이해하지 못해 쓰지 않음
                // reloadData가 하는 일에 대해서 이해하는데에만 아래코드를 사용함(애니메이션은 아래것이 효과적이긴함)
                /*
                // 셀의 내용을 직접 수정한다.
                let cell = self.tableView.cellForRow(at: indexPath)
                cell?.textLabel?.text = title
                cell?.detailTextLabel?.text = contents
                // 수정된 셀을 첫 번째 행으로 이동시킨다.
                let firstIndexPath = IndexPath(item: 0, section: 0)
                self.tableView.moveRow(at: indexPath, to: firstIndexPath)
                */
            }
        })
        self.present(alert, animated: false) // 알림창을 화면에 표시
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let object = self.list[indexPath.row]
        let uvc = self.storyboard?.instantiateViewController(withIdentifier: "LogVC") as! LogVC
        uvc.board = object as? BoardMO
        self.show(uvc, sender: self)
    }
}
