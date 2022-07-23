import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/components/BucketListView.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/pages/list/list_edit.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/list_store.dart';

class ListPage extends StatefulWidget {
  final TaskList taskList;

  //ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));
  ListPage({this.taskList}) : super(key: Key(Random().nextInt(100000).toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  int _viewIndex = 0;
  TaskList _list;
  List<Task> _loadingTasks = [];
  int _currentPage = 1;
  bool _loading = true;
  bool displayDoneTasks;
  ListProvider taskState;

  @override
  void initState() {
    _list = TaskList(
      id: widget.taskList.id,
      title: widget.taskList.title,
      tasks: [],
    );
    super.initState();
    Future.delayed(Duration.zero, (){
      _loadList();
    });
  }

  @override
  Widget build(BuildContext context) {
    taskState = Provider.of<ListProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_list.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListEditPage(
                    list: _list,
                  ),
                )).whenComplete(() => _loadList()),
          ),
        ],
      ),
      // TODO: it brakes the flow with _loadingTasks and conflicts with the provider
      body: !taskState.isLoading
          ? RefreshIndicator(
              child: taskState.tasks.length > 0 || taskState.buckets.length > 0
                  ? ListenableProvider.value(
                      value: taskState,
                      child: Theme(
                        data: (ThemeData base) {
                          return base.copyWith(
                            chipTheme: base.chipTheme.copyWith(
                              labelPadding: EdgeInsets.symmetric(horizontal: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                              ),
                            ),
                          );
                        }(Theme.of(context)),
                        child: () {
                          switch (_viewIndex) {
                            case 0:
                              return _listView(context);
                            case 1:
                              return _kanbanView(context);
                            default:
                              return _listView(context);
                          }
                        }(),
                      ),
                    )
                  : Center(child: Text('This list is empty.')),
              onRefresh: _loadList,
            )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton(
            onPressed: () => _addItemDialog(context), child: Icon(Icons.add)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: 'List',
            tooltip: 'List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_kanban),
            label: 'Kanban',
            tooltip: 'Kanban',
          ),
        ],
        currentIndex: _viewIndex,
        onTap: _onViewTapped,
      ),
    );
  }

  void _onViewTapped(int index) {
    _loadList().then((_) {
      _currentPage = 1;
      setState(() {
        _viewIndex = index;
      });
    });
  }

  ListView _listView(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      itemBuilder: (context, i) {
        if (i.isOdd) return Divider();

        if (_loadingTasks.isNotEmpty) {
          final loadingTask = _loadingTasks.removeLast();
          return _buildLoadingTile(loadingTask);
        }

        final index = i ~/ 2;

        // This handles the case if there are no more elements in the list left which can be provided by the api
        if (taskState.maxPages == _currentPage &&
            index == taskState.tasks.length)
          return null;

        if (index >= taskState.tasks.length &&
            _currentPage < taskState.maxPages) {
          _currentPage++;
          _loadTasksForPage(_currentPage);
        }
        return index < taskState.tasks.length
            ? _buildTile(taskState.tasks[index])
            : null;
      }
    );
  }

  ListView _kanbanView(BuildContext buildContext) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, i) {
        if (taskState.maxPages == _currentPage && i >= taskState.buckets.length) {
          if (i == taskState.buckets.length)
            return _buildBucketTile();
          return null;
        }

        if (i >= taskState.buckets.length && _currentPage < taskState.maxPages) {
          _currentPage++;
          _loadBucketsForPage(_currentPage);
        }
        return i < taskState.buckets.length
            ? _buildBucketTile(taskState.buckets[i])
            : null;
      },
    );
  }

  TaskTile _buildTile(Task task) {
    return TaskTile(
      task: task,
      loading: false,
      onEdit: () {
        /*Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TaskEditPage(
                  task: task,
                ),
          ),
        );*/
      },
      onMarkedAsDone: (done) {
        Provider.of<ListProvider>(context, listen: false).updateTask(
          context: context,
          id: task.id,
          done: done,
        );
      },
    );
  }

  Container _buildBucketTile([Bucket bucket]) {
    final deviceData = MediaQuery.of(context);
    return Container(
      width: deviceData.size.width
          * (deviceData.orientation == Orientation.portrait ?  0.8 : 0.4),
      child: Column(
        children: () {
          if (bucket != null) {
            return <Widget>[
              ListTile(
                title: Text(
                  bucket.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                trailing: Icon(Icons.more_vert),
              ),
              Expanded(
                child: BucketListView(
                  bucket: bucket,
                  onAddTask: () => _addItemDialog(context, bucket),
                ),
              ),
            ];
          } else {
            return <Widget>[
              ListTile(
                title: TextButton.icon(
                  onPressed: () => _addBucketDialog(context),
                  label: Text('Create Bucket'),
                  style: ButtonStyle(alignment: Alignment.centerLeft),
                  icon: Icon(Icons.add),
                ),
              ),
              Spacer(),
            ];
          }
        }(),
      ),
    );
  }

  Future<void> updateDisplayDoneTasks() {
    return VikunjaGlobal.of(context).listService.getDisplayDoneTasks(_list.id)
        .then((value) {displayDoneTasks = value == "1";});
  }

  TaskTile _buildLoadingTile(Task task) {
    return TaskTile(
      task: task,
      loading: true,
      onEdit: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskEditPage(
            task: task,
          ),
        ),
      ),
    );
  }

  Future<void> _loadList() async {
    updateDisplayDoneTasks().then((value) {
      switch (_viewIndex) {
        case 0:
          _loadTasksForPage(1);
          break;
        case 1:
          _loadBucketsForPage(1);
          break;
        default:
          _loadTasksForPage(1);
      }
    });
  }

  void _loadTasksForPage(int page) {
    Provider.of<ListProvider>(context, listen: false).loadTasks(
      context: context,
      listId: _list.id,
      page: page,
      displayDoneTasks: displayDoneTasks ?? false
    );
  }

  void _loadBucketsForPage(int page) {
    Provider.of<ListProvider>(context, listen: false).loadBuckets(
      context: context,
      listId: _list.id,
      page: page
    );
  }

  _addItemDialog(BuildContext context, [Bucket bucket]) {
    showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addItem(title, context, bucket),
        decoration: InputDecoration(
          labelText: (bucket != null ? '${bucket.title}: ' : '') + 'New Task Name',
          hintText: 'eg. Milk',
        ),
      ),
    );
  }

  _addItem(String title, BuildContext context, [Bucket bucket]) {
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
      id: null,
      title: title,
      createdBy: globalState.currentUser,
      done: false,
      bucketId: bucket?.id,
    );
    setState(() => _loadingTasks.add(newTask));
    Provider.of<ListProvider>(context, listen: false)
        .addTask(
      context: context,
      newTask: newTask,
      listId: _list.id,
    )
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully' + (bucket != null ? ' to ${bucket.title}' : '') + '!'),
      ));
      setState(() {
        _loadingTasks.remove(newTask);
      });
    });
  }

  _addBucketDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addBucket(title, context),
        decoration: InputDecoration(
          labelText: 'New Bucket Name',
          hintText: 'eg. To Do',
        ),
      )
    );
  }

  _addBucket(String title, BuildContext context) {
    Provider.of<ListProvider>(context, listen: false).addBucket(
      context: context,
      newBucket: Bucket(
        id: null,
        title: title,
        createdBy: VikunjaGlobal.of(context).currentUser,
        listId: _list.id,
      ),
      listId: _list.id,
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The bucket was added successfully!'),
      ));
      setState(() {});
    });
  }
}
