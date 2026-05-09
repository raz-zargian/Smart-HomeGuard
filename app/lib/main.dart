import 'package:app/event_detail_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      //home: const MyHomePage(title: 'Flutter Demo Home Page'),
      home: const EventDetailScreen(
        eventId: 'b2380929-e63a-40a5-8c8f-3c9d3941a352',
        imageUrl:
            'https://smarthomeguard-images.s3.amazonaws.com/events/b2380929-e63a-40a5-8c8f-3c9d3941a352.jpg?AWSAccessKeyId=ASIAWMO6PDFSDGED6UOJ&Signature=ABt0NGvkv%2FeamzQHfGZ1cXbcEsk%3D&x-amz-security-token=IQoJb3JpZ2luX2VjECMaCXVzLWVhc3QtMSJGMEQCIBvnQHgm%2BuUBp%2F%2FFZARbiw1Gb6zPndUwUHYSEWNNrKY1AiAOAj6Xv9S31D3zRv3%2FC2xmBqOoaiUSys2SHRMhUCjc4Cr4Awjs%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAIaDDQzOTA5MDA5MjM4OCIMbr6dXRusQhv88%2B%2FvKswD5LwoJ1PxqWbqDhOnc7I2OpNmvPYvGMGyKY6a7pE0CcLD7KECfEpUXmZAKAp5%2Bgbdn9qTLrZzXjJ6%2FIQ7bUA%2BSpNd4aYbtBLTuLiwMOWI2grk9WrfVzWeebQ40az8%2FQ1lfT4vzW8AcWicIAvIi%2FR0RzFbTHTiyS99KdWtSaKnWFdpjkzmGJDmn4gBJnx64W53M7HbF0jW%2BHxw%2FThAx9q4nfNdxMCeThooumUwZwEgQOOPvIWrOk0nCjnfknhWZ%2Bz8qkoGzsQGNMMvrRUYZ0s7GDMzWD%2BUK4Kom0cYFlGuTu204Pv7sWLCOO5jEHHJ2OdASNfdSW4D5sjyEcm5HawrlV2Vj6cujdk93onv1tLF3Q8CUlBzMuU7TVUbEBqqP61cofwB57z1oDOvPgycwetfGoSD9AbLYpk3rhpj8CDsJQF6G8nS6xca7C0H74pQPDsX1G85bvXzxZ1pS0Y4N2xglsoyYQpzpRQbpAzdYQIt6gtNTRq6FEEiYa2l1EJt9nLNRMaMAGH7OP9k1BXj51URUK%2FoheDwLFowwi%2Bay%2BJY%2Fg2dgVge2BOd6dL9p%2BR0ui7WuqdIWsSengqQWmrWIhg3kO%2FSrvNP04LGrEkaKzDGh%2F7PBjqiAaWmMvx1F%2F8QybU0wRcp9Yh0gPYUVQN9DA7Bam4Ffh1vxRKWrrf9EkRJ8jduEIjxK9OBokQ4vGLmvT8IygNudb2icEAOedwoS9HTPDd7NnoUVnq8gjJg4ewIOjZB52BkhvaEq1tHmQ%2Bk2vCbm2ZUWNleUOU%2BDs9rFoKG%2BMc9CH4DSunTQRViL%2FxJSZiPtG7DALsgAiw0qFWhZUm58J2%2FMqzbDw%3D%3D&Expires=1778356696', // תמונת דמה כדי לבדוק שהעיצוב עובד
      ),
    );
  }
}
