<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Example extends Model
{
    protected $connection = 'oracle';
    protected $table = 'example_table_user';
}
